{
  flake.modules.nixos.core-networking = {
    networking.networkmanager.enable = true;
    # Some routers only advertise themselves as a DNS server over IPv6
    # link-local (fe80::...) and don't answer there, so every lookup times
    # out while ping-by-IP works. Put known-good resolvers ahead of whatever
    # DHCP hands out; the router's own are still there as a fallback.
    networking.networkmanager.insertNameservers = [
      "1.1.1.1"
      "9.9.9.9"
    ];
    # MagicDNS (Tailscale) needs systemd-resolved as the resolver.
    services.resolved.enable = true;
  };
}
