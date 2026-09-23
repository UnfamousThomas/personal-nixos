{
  flake.modules.nixos.core-networking = {
    networking.networkmanager.enable = true;
    # MagicDNS (Tailscale) needs systemd-resolved as the resolver.
    services.resolved.enable = true;
  };
}
