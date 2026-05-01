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
      model = {
        provider = "openrouter";
        default = "nvidia/nemotron-3-super-120b-a12b:free";
      };
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

  system.activationScripts."hermes-cli-home-link" = lib.stringAfter [ "hermes-agent-setup" ] ''
    if [ -d /home/hermes/.hermes ] && [ ! -L /home/hermes/.hermes ]; then
      mv /home/hermes/.hermes "/home/hermes/.hermes.unmanaged-backup.$(date +%s)"
    fi
    ln -sfn /var/lib/hermes/.hermes /home/hermes/.hermes
    chown -h hermes:hermes /home/hermes/.hermes
  '';
}
