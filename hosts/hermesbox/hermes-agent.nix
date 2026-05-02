{ hermes-agent, lib, pkgs, ... }:

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
        default = "google/gemini-2.5-flash-lite";
        # Keep in mind as a future free fallback candidate, but not as the default.
        # nvidia/nemotron-3-super-120b-a12b:free has poor practical limits right now.
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
      unauthorized_dm_behavior = "pair";
      whatsapp = {
        unauthorized_dm_behavior = "ignore";
        dm_policy = "allowlist";
        allow_from = "905333526660";
      };
      platforms.whatsapp.extra.bridge_script = "/var/lib/hermes/.hermes/platforms/whatsapp/bridge/bridge.js";
      telegram = {
      };
    };

    environment = {
      WHATSAPP_ENABLED = "true";
      WHATSAPP_MODE = "self-chat";
      WHATSAPP_ALLOWED_USERS = "905333526660";
      WHATSAPP_HOME_CHANNEL = "905333526660";
      WHATSAPP_HOME_CHANNEL_NAME = "Berker WhatsApp";
      TELEGRAM_ENABLED = "true";
      TELEGRAM_BOT_TOKEN = "8714198490:AAGEpAzwePrBxVONxKkbvAJu1d2Vf0wASww";
      TELEGRAM_ALLOWED_USERS = "2052314937";
      TELEGRAM_HOME_CHANNEL = "2052314937";
      TELEGRAM_HOME_CHANNEL_NAME = "Berker Telegram";
    };

    extraPackages = with pkgs; [
      curl
      fd
      git
      jq
      nodejs_22
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

  system.activationScripts."hermes-whatsapp-bridge" = lib.stringAfter [ "hermes-agent-setup" ] ''
    bridge_dir=/var/lib/hermes/.hermes/platforms/whatsapp/bridge
    mkdir -p "$bridge_dir"
    cp -r --no-preserve=mode,ownership ${hermes-agent.outPath}/scripts/whatsapp-bridge/. "$bridge_dir/"
    chown -R hermes:hermes /var/lib/hermes/.hermes/platforms/whatsapp
    chmod -R u+rwX,go-rwx /var/lib/hermes/.hermes/platforms/whatsapp
  '';
}
