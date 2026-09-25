{
  config,
  inputs,
  ...
}:
let
  inherit (config.flake.modules) homeManager;
in
{
  # The Pi coding agent setup lives in ../../../pi, self-contained so it can be
  # shared (see pi/README.md). This file is the glue: it exports that bundle
  # from this flake and adds this machine's own choices on top.

  # Everything Pi needs in `pkgs`; also part of overlays.default (flake/overlays.nix).
  flake.overlays.pi = import ../../../pi/overlay.nix {
    minecraftMcpServerSrc = inputs.minecraft-mcp-server;
  };

  # The options-driven module, for other flakes / Home Manager configs (needs
  # overlays.pi applied) and for this flake's own hosts.
  flake.homeModules.pi-agent = ../../../pi/home-module.nix;
  flake.modules.homeManager.pi-agent = ../../../pi/home-module.nix;

  # This setup's own choices (the shareable defaults are in the module).
  flake.modules.homeManager.pi =
    { lib, pkgs, ... }:
    let
      # Identifiers, not credentials (the API key stays in Pi's auth.json).
      # `route` is the name of the dynamic route in the gateway's dashboard.
      cloudflare = {
        accountId = "9385abe16a000b20251ec20bccd53903";
        gatewayId = "test-gateway";
        route = "pi";
      };
    in
    {
      imports = [ homeManager.pi-agent ];

      programs.pi-agent = {
        enable = true;

        # Drives a Minestom test server. Bot name and address are the defaults
        # for a local dev server; see pi/packages/minecraft-mcp-server.nix for
        # the supported Minecraft versions.
        mcp.servers.minecraft = {
          command = lib.getExe pkgs.minecraft-mcp-server;
          args = [
            "--host"
            "localhost"
            "--port"
            "25565"
            "--username"
            "PiBot"
          ];
        };

        # Routing lives in Cloudflare AI Gateway, not in Pi: a dynamic route
        # (dashboard: AI Gateway > Routes) tries Sonnet 5, then gpt-6-sol, then
        # Sonnet 4.6, moving on when a provider errors or is rate-limited. Pi's
        # own router (pi-auto-model) is off: it hopped between vendors, which
        # re-sends the whole conversation uncached on every switch (a 50-90K
        # turn costs $0.10-0.30 instead of ~$0.02), and it could not fail over
        # cleanly on a 429 ("no approved route plan available").
        #
        # Dynamic routes are only reachable through the gateway's OpenAI-
        # compatible /compat endpoint, so the route is its own provider here;
        # Claude and subagents pinned below keep using the native endpoint.
        # The key is read from Pi's own auth.json at request time (the one
        # from `pi` /login), so nothing secret lands in the store.
        autoModel.enable = false;

        env = {
          CLOUDFLARE_ACCOUNT_ID = cloudflare.accountId;
          CLOUDFLARE_GATEWAY_ID = cloudflare.gatewayId;
        };

        models.providers.cloudflare-dynamic =
          let
            key = "${lib.getExe pkgs.jq} -r '.\"cloudflare-ai-gateway\".key' ~/.pi/agent/auth.json";
          in
          {
            baseUrl = "https://gateway.ai.cloudflare.com/v1/${cloudflare.accountId}/${cloudflare.gatewayId}/compat";
            api = "openai-completions";
            apiKey = "!${key}";
            headers."cf-aig-authorization" = "!printf 'Bearer %s' \"$(${key})\"";
            models = [
              {
                id = "dynamic/${cloudflare.route}";
                name = "Cloudflare route: ${cloudflare.route}";
                # Off until you have seen thinking work through /compat: it is
                # sent as reasoning_effort, which the gateway translates for
                # Anthropic models. Turn on with `reasoning = true`.
                reasoning = false;
                input = [ "text" ];
                contextWindow = 1000000;
                maxTokens = 64000;
                # Sonnet 5 prices, for Pi's cost display (a fallback bills as
                # the model that actually answered).
                cost = {
                  input = 2;
                  output = 10;
                  cacheRead = 0.2;
                  cacheWrite = 2.5;
                };
              }
            ];
          };

        settingsDefaults = {
          defaultProvider = "cloudflare-dynamic";
          defaultModel = "dynamic/${cloudflare.route}";

          # Cost: you pay the cache-read price on the whole context every turn,
          # and Pi only compacts at (window - 16K), so on 1M-token models a
          # long session drifts up to hundreds of thousands of tokens per turn.
          # Compact at ~120K instead (reserveTokens = 1M window - 120K).
          # Per-model, so a small-window model never ends up compacting on
          # every turn.
          compaction.modelOverrides =
            let
              compactAt120k = {
                reserveTokens = 880000;
                keepRecentTokens = 20000;
              };
            in
            {
              "cloudflare-dynamic/dynamic/${cloudflare.route}" = compactAt120k;
              "cloudflare-ai-gateway/claude-sonnet-5" = compactAt120k;
              "cloudflare-ai-gateway/claude-opus-5.5" = compactAt120k;
            };
        };

        # Subagents are one-shot workers, so they are pinned to concrete models
        # on the native gateway endpoint (prompt caching is known to work there).
        #
        # Cost: every subagent starts cold, so the expensive model goes where
        # an independent second opinion pays off (the reviewer). Implementers
        # work from a tight brief and are checked by the build, the tests and
        # the reviewer, so Sonnet does that well for a fraction of the price.
        agents =
          let
            gw = m: "cloudflare-ai-gateway/${m}";
            worker = {
              model = gw "claude-sonnet-5";
              thinking = "medium";
            };
          in
          {
            explorer = {
              model = gw "claude-sonnet-5";
              thinking = "low";
            };
            implementer = worker;
            go-implementer = worker;
            kotlin-implementer = worker;
            nix-implementer = worker;
            ansible-implementer = worker;
            reviewer = {
              model = gw "claude-opus-5.5";
              thinking = "medium";
            };
          };
      };
    };
}
