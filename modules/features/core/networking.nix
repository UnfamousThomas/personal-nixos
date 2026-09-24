{
  flake.modules.nixos.core-networking =
    { lib, ... }:
    {
      networking.networkmanager.enable = true;
      # Some routers advertise only an IPv6 link-local DNS server
      # (fe80::...) that doesn't answer, so lookups time out while
      # ping-by-IP works. NetworkManager therefore passes no DHCP/RA DNS to
      # the resolver (dns = "none"), and resolved uses the fixed public
      # servers below on every network. Tailscale registers its MagicDNS
      # domains with resolved directly. Trade-off: names only a network's own
      # DNS knows (a work/campus intranet) don't resolve.
      # mkForce: the resolved module sets this to "systemd-resolved".
      networking.networkmanager.dns = lib.mkForce "none";
      # MagicDNS (Tailscale) needs systemd-resolved as the resolver.
      services.resolved = {
        enable = true;
        settings.Resolve = {
          DNS = [
            "1.1.1.1"
            "9.9.9.9"
          ];
          FallbackDNS = [
            "1.0.0.1"
            "149.112.112.112"
          ];
          # `~.` = use these for every name, not only names nothing else claims.
          Domains = [ "~." ];
        };
      };
    };
}
