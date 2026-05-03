{ lib, ... }:

let
  gmailAddress = "therearenothings@gmail.com";
  gmailPasswordCmd = "/bin/sh -lc \"set -a; . /home/hermes/.keys/hermes.env >/dev/null 2>&1; printf %s \\\"$GMAIL_APP_PASSWORD\\\"\"";
in
{
  # Declaratively render Himalaya config outside the Nix store, with secrets pulled
  # at runtime from /home/hermes/.keys/hermes.env.
  system.activationScripts."himalaya-config" = lib.stringAfter [ "users" ] ''
    install -d -m 0700 -o hermes -g hermes /home/hermes/.config/himalaya

    cat > /home/hermes/.config/himalaya/config.toml <<'EOF'
[accounts.default]
default = true
email = "${gmailAddress}"
display-name = "Hermes"

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
