{
  # Each host lives outside ./modules (so disko.nix / facter.json next to it
  # are never mistaken for flake-parts modules by import-tree) and is
  # brought in explicitly here. Adding a third host is exactly one more
  # line, plus a new hosts/<name>/ directory.
  imports = [
    ../../hosts/thomas-laptop
    ../../hosts/thomas-desktop
  ];
}
