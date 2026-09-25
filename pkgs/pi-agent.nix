{
  lib,
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
}:
# Pi with the language servers, linters and formatters it should see on PATH.
# Full toolchains (Go, JDKs, Ansible itself) stay in per-project devenv shells
# on purpose (see modules/features/apps/zed/zed.nix); nodejs and uv are here
# because `npx` / `uvx` based MCP servers need them.
symlinkJoin {
  name = "pi-agent-${pi-coding-agent.version}";
  paths = [ pi-coding-agent ];
  nativeBuildInputs = [ makeBinaryWrapper ];
  postBuild = ''
    wrapProgram $out/bin/pi --suffix PATH : ${
      lib.makeBinPath [
        nodejs
        uv
        gh
        jq
        gopls
        golangci-lint
        kotlin-lsp
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
    }
  '';
  inherit (pi-coding-agent) meta;
}
