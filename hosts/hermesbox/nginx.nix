{ config, pkgs, ... }:

{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts = {
      "dash.otto" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:9119";
          proxyWebsockets = true;
        };
      };
      "usage.otto" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:9121";
        };
      };
      "work.otto" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:9130";
          proxyWebsockets = true;
        };
      };
    };
  };

  # Open HTTP port on the Tailscale interface
  networking.firewall.allowedTCPPorts = [ 80 ];
}
