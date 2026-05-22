{ lib, ... }:

let
  gmailAddress = "therearenothings@gmail.com";
  hermesEnvFile = "/run/secrets/hermes.env";
  legacyHermesEnvFile = "/home/hermes/.keys/hermes.env";
  passwordScript = "/home/hermes/.local/bin/himalaya-password.sh";
in
{
  # Declaratively render Himalaya config outside the Nix store, with secrets
  # pulled at runtime from a thin shell wrapper script (avoids the multi-layer
  # shell-escaping hell that plagued the old inline auth.cmd approach).
  system.activationScripts."himalaya-config" = lib.stringAfter [ "users" ] ''
    install -d -m 0700 -o hermes -g hermes /home/hermes/.config/himalaya
    install -d -m 0755 -o hermes -g hermes /home/hermes/.local/bin

    # Thin password wrapper — cleaner than nested-shell quoting in auth.cmd.
    cat > ${passwordScript} <<'SHEOF'
#!/bin/sh
# Read GMAIL_APP_PASSWORD from the sops-nix env file (or legacy fallback).
env_file=${hermesEnvFile}
[ -r "$env_file" ] || env_file=${legacyHermesEnvFile}
. "$env_file" >/dev/null 2>&1
printf '%s' "$GMAIL_APP_PASSWORD"
SHEOF
    chmod 0500 ${passwordScript}
    chown hermes:hermes ${passwordScript}

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
backend.auth.cmd = '${passwordScript}'

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
auth.cmd = '${passwordScript}'
EOF

    chown hermes:hermes /home/hermes/.config/himalaya/config.toml
    chmod 0600 /home/hermes/.config/himalaya/config.toml
  '';
}
