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

        # Cloudflare AI Gateway (built into Pi as a provider): once there is a
        # gateway, put its non-secret IDs here and log in with `pi` /login (or
        # export CLOUDFLARE_API_KEY) for the key, then switch to it in /model.
        #   env = {
        #     CLOUDFLARE_ACCOUNT_ID = "...";
        #     CLOUDFLARE_GATEWAY_ID = "...";
        #   };
      };
    };
}
