{ inputs, ... }:
{
  # Enables the `flake.modules.<class>.<name>` option namespace that every
  # feature file below contributes to -- the core of the Dendritic pattern.
  # https://flake.parts/options/flake-parts-modules.html
  imports = [ inputs.flake-parts.flakeModules.modules ];

  systems = [ "x86_64-linux" ];
}
