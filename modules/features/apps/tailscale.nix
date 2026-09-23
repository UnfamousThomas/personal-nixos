{
  # MagicDNS relies on services.resolved (enabled in core-networking).
  # Authenticate after install with `sudo tailscale up` -- see README.
  flake.modules.nixos.tailscale = {
    services.tailscale.enable = true;
  };
}
