{
  description = "Thomas's personal, reproducible, multi-host NixOS configuration";

  # Lets `nix build`/`run`/`nixos-install --flake` pick these substituters up
  # BEFORE the system is installed (the equivalent `nix.settings` in
  # features/core/nix-settings.nix only takes effect once already switched
  # to). Without this, a from-scratch install compiles Noctalia's
  # Quickshell/Qt6 stack from source instead of fetching it -- easily
  # enough to OOM a machine with 8GB RAM. Untrusted flakes don't get this
  # applied automatically; pass `--accept-flake-config` (or set
  # `accept-flake-config = true` in nix.conf) the first time.
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://noctalia.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    import-tree.url = "github:vic/import-tree";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.home-manager.follows = "home-manager";
    agenix.inputs.darwin.follows = "";

    # CLI the install app (modules/flake/install-app.nix) runs to generate
    # hosts/<name>/facter.json. The NixOS-side consumer of that report is
    # nixpkgs' own built-in `hardware.facter` module, so this input is only
    # ever used as a tool, never imported as a module.
    nixos-facter.url = "github:nix-community/nixos-facter";
    nixos-facter.inputs.nixpkgs.follows = "nixpkgs";

    stylix.url = "github:nix-community/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    # Deliberately NOT followed: following nixpkgs here changes Noctalia's
    # derivation hashes and forfeits its prebuilt binary cache
    # (noctalia.cachix.org), forcing a full local Quickshell/Qt6 rebuild.
    # See https://docs.noctalia.dev/noctalia/getting-started/nixos/
    noctalia.url = "github:noctalia-dev/noctalia";

    # Upstream's own flake -- deliberately NOT nixpkgs' `opencode` package,
    # which lags behind releases (per user request). Not followed, to keep
    # their pinned Bun/native-build recipe intact.
    opencode.url = "github:sst/opencode";

    # OpenWave ships its own maintained flake (rust-overlay + buildRustPackage);
    # use it directly rather than re-packaging.
    openwave.url = "github:rikkichy/openwave";
    openwave.inputs.nixpkgs.follows = "nixpkgs";

    # Minecraft bot MCP server for testing Minestom servers. A plain source
    # input: upstream ships no flake, and updating (or pointing this at a
    # fork, e.g. for newer Minecraft versions) is one line here plus
    # `nix flake update minecraft-mcp-server`; pkgs/minecraft-mcp-server.nix
    # then needs its npmDepsHash refreshed if the lockfile changed.
    minecraft-mcp-server.url = "github:yuniko-software/minecraft-mcp-server";
    minecraft-mcp-server.flake = false;

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
