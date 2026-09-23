{
  description = "Thomas's personal, reproducible, multi-host NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    # CLI used at install time to generate hosts/<name>/facter.json.
    # The NixOS-side consumer of that report is nixpkgs' own built-in
    # `hardware.facter` module (nixos-facter-modules is archived/upstreamed),
    # so this input is only ever used as a tool, never imported as a module.
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

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
