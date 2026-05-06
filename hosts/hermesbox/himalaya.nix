{ lib, ... }:

let
  gmailAddress = "therearenothings@gmail.com";
  hermesEnvFile = "/run/secrets/hermes.env";
  legacyHermesEnvFile = "/home/hermes/.keys/hermes.env";
  gmailPasswordCmd = "/bin/sh -lc \"env_file=${hermesEnvFile}; [ -r \\\"$env_file\\\" ] || env_file=${legacyHermesEnvFile}; set -a; . \\\"$env_file\\\" >/dev/null 2>&1; printf %s \\\"$GMAIL_APP_PASSWORD\\\"\"";
in
{
  # Declaratively render Himalaya config outside the Nix store, with secrets
  # pulled at runtime from sops-nix's /run/secrets/hermes.env, falling back to
  # the legacy operator-managed env file during migration.
  system.activationScripts."himalaya-config" = lib.stringAfter [ "users" ] ''
    install -d -m 0700 -o hermes -g hermes /home/hermes/.config/himalaya

    cat > /home/hermes/.config/himalaya/config.toml <<'EOF'
[accounts.default]
default = true
email = "${gmailAddress}"
display-name = "Otto"
signature = "My best,\nOtto\nAvatar: /home/hermes/avatar.jpg\n\n<i>Autonomous AI assistant instance (Otto), developed on Hermes Agent by Nous Research.</i>"
signature-delim = "-- \n"

backend.type = "imap"
backend.host = "imap.gmail.com"
backend.port = 993
backend.encryption.type = "tls"
backend.login = "${gmailAddress}"
backend.auth.type = "password"
backend.auth.cmd = '${gmailPasswordCmd}'

folder.aliases.inbox = "INBOX"
folder.aliases.sent = "[Gmail]/Sent Mail"
folder.aliases.drafts = "[Gmail]/Drafts"
folder.aliases.trash = "[Gmail]/Trash"

[accounts.default.message.send.backend]
type = "smtp"
host = "smtp.gmail.com"
port = 587
encryption.type = "start-tls"
login = "${gmailAddress}"
auth.type = "password"
auth.cmd = '${gmailPasswordCmd}'
EOF

    chown hermes:hermes /home/hermes/.config/himalaya/config.toml
    chmod 0600 /home/hermes/.config/himalaya/config.toml
  '';
}
