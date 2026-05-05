{ pkgs, ... }:

{
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  services.tailscale = {
    enable = true;
    package = pkgs.tailscale;

    # Runtime secret managed outside Git/Nix store by the operator.
    # This enrolls the VM non-interactively into Berker's tailnet.
    authKeyFile = "/home/hermes/.keys/tailscale-authkey";

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
