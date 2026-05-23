{ config, lib, ... }:

{
  sops.defaultSopsFile = ./secrets.yaml;
  sops.defaultSopsFormat = "yaml";

  # One shared Otto age key, intentionally reused across Otto hosts for simpler
  # migration. Berker keeps a private fallback copy out of band; new hosts get
  # this same key copied into place before the first rebuild.
  sops.age.keyFile = "/home/hermes/.keys/sops-age-otto-shared.txt";

  sops.secrets."hermes/env" = {
    owner = "hermes";
    group = "hermes";
    mode = "0400";
    path = "/run/secrets/hermes.env";
  };

  sops.secrets."tailscale/authkey" = {
    owner = "root";
    group = "root";
    mode = "0400";
    path = "/run/secrets/tailscale-authkey";
  };

  assertions = [
    {
      assertion = lib.pathExists ./secrets.yaml;
      message = "hosts/hermesbox/secrets.yaml must exist and be sops-encrypted before rebuilding hermesbox.";
    }
  ];
}
