{ lib, pkgs, ... }:

{
  users.groups.hermes = { };

  users.users.hermes.extraGroups = [ "hermes" ];

  services.hermes-agent = {
    enable = true;
    createUser = false;
    user = "hermes";
    group = "hermes";

    # Keep the CLI and gateway on the same managed state directory.
    addToSystemPackages = true;

    # Provider secrets should live here temporarily, then move to sops-nix/agenix.
    environmentFiles = [ "/var/lib/hermes/env" ];

    settings = {
      toolsets = [ "all" ];
      terminal = {
        backend = "local";
        timeout = 180;
      };
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
      };
    };

    extraPackages = with pkgs; [
      curl
      fd
      git
      jq
      ripgrep
      tree
      wget
    ];
  };

  # Hermes is installed and configured declaratively, but the gateway should not
  # auto-start until the model provider and secret/auth strategy are chosen.
  systemd.services.hermes-agent.wantedBy = lib.mkForce [ ];
}
