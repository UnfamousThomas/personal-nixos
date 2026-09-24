{
  flake.modules.nixos.core-networking =
    { lib, ... }:
    {
      networking.networkmanager.enable = true;
      # Some routers only advertise themselves as a DNS server over IPv6
      # link-local (fe80::...) and don't answer there, so every lookup times
      # out while ping-by-IP works. So NetworkManager doesn't hand
      # DHCP/RA-provided DNS to the resolver at all (dns = "none"; a
      # `resolvectl dns` override doesn't stick, NetworkManager re-applies its
      # own), and resolved uses these servers on every network instead.
      # Tailscale still registers its MagicDNS domains with resolved directly.
      # The cost: DNS handed out by a network is ignored, so names that only
      # that network's own DNS knows (a work/campus intranet) won't resolve.
      # (mkForce: the resolved module sets this to "systemd-resolved" itself.)
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
