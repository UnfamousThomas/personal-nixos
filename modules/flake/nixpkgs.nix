{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      # The nixpkgs instance used for perSystem outputs (devShells, the
      # formatter, custom packages evaluated standalone). Unfree + the
      # overlay are applied here so this instance matches every host's.
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ inputs.self.overlays.default ];
      };
    };
}
