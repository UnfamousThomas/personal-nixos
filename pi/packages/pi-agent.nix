{
  lib,
  stdenv,
  symlinkJoin,
  makeBinaryWrapper,
  pi-coding-agent,
  # Runtime tools: what the model's bash tool and the LSP/MCP servers Pi
  # launches can reach. Appended to PATH (not prepended), so a project's own
  # devenv toolchain (go, gopls, ansible, a JDK, ...) wins inside its shell.
  nodejs,
  uv,
  gh,
  jq,
  gopls,
  golangci-lint,
  kotlin-lsp,
  nixd,
  nixfmt,
  yaml-language-server,
  yamlfmt,
  ansible-language-server,
  ansible-lint,
  bash-language-server,
  shellcheck,
  shfmt,
  # More tools to put on PATH (`pkgs.pi-agent.override { extraPackages = [ ... ]; }`).
  extraPackages ? [ ],
  # Environment defaults for Pi, for settings that aren't secret (Cloudflare
  # account/gateway IDs, a proxy, ...). Set as defaults on the wrapper, so they
  # reach Pi whichever way it is started (a terminal, Zed's pi-acp, ...) and a
  # variable already set in the environment still wins. Everything here ends up
  # in the Nix store: never put a key or token in it.
  env ? { },
}:
# Pi with the language servers, linters and formatters it should see on PATH.
# Full toolchains (Go, JDKs, Ansible itself) stay in per-project devenv shells
# on purpose; nodejs and uv are here because `npx` / `uvx` based MCP servers
# need them.
symlinkJoin {
  name = "pi-agent-${pi-coding-agent.version}";
  paths = [ pi-coding-agent ];
  nativeBuildInputs = [ makeBinaryWrapper ];
  postBuild = ''
    wrapProgram $out/bin/pi --suffix PATH : ${
      lib.makeBinPath (
        [
          nodejs
          uv
          gh
          jq
          gopls
          golangci-lint
          nixd
          nixfmt
          yaml-language-server
          yamlfmt
          ansible-language-server
          ansible-lint
          bash-language-server
          shellcheck
          shfmt
        ]
        # JetBrains ships this for x86_64-linux only (see kotlin-lsp.nix).
        ++ lib.optional (lib.meta.availableOn stdenv.hostPlatform kotlin-lsp) kotlin-lsp
        ++ extraPackages
      )
    } ${
      lib.concatStringsSep " " (
        lib.mapAttrsToList (
          n: v:
          lib.escapeShellArgs [
            "--set-default"
            n
            v
          ]
        ) env
      )
    }
  '';
  inherit (pi-coding-agent) meta;
}
