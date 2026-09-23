{ lib }:
{
  facter = import ./facter.nix { inherit lib; };
}
