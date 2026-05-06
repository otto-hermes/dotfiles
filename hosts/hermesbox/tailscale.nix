{ config, pkgs, ... }:

{
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  services.tailscale = {
    enable = true;
    package = pkgs.tailscale;

    # Runtime secret decrypted by sops-nix. The file contains an auth key only,
    # not Tailscale machine state; fresh hosts should enroll, not copy state DBs.
    authKeyFile = config.sops.secrets."tailscale/authkey".path;

    # Allow Otto to be reached privately over Tailscale SSH and give it a stable tailnet name.
    extraUpFlags = [
      "--hostname=otto-hermes"
      "--ssh"
    ];

    # Prepare the VM to act as a Germany exit node. Admin-console approval is still required.
    useRoutingFeatures = "server";
    extraSetFlags = [
      "--advertise-exit-node"
    ];
  };

  environment.systemPackages = with pkgs; [
    tailscale
  ];
}
