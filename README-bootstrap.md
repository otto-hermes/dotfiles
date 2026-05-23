# Otto on-prem rebuild and migration guide

Last updated: 2026-05-13 11:12 +0300

This is the zero-drama rebuild path for moving Otto/Hermes from the current VPS to an on-prem NixOS host. The goal is no data loss, no personality loss, no secret leakage, and a rollback path until the new node is proven.

Canonical GitHub sources:

- Declarative host config: `https://github.com/otto-hermes/dotfiles`
- Safe Otto brain mirror: `https://github.com/otto-hermes/hermes-brain`

Do not clone the VPS wholesale. Rebuild the machine declaratively, restore only intentional state, then validate every capability before cutover.

## 0. What must survive

These are the non-negotiable Otto soul/state layers:

| Layer | Source of truth | Restore method |
| --- | --- | --- |
| NixOS/system/app config | `otto-hermes/dotfiles` | clone repo, select host flake, `nixos-rebuild switch` |
| Encrypted secrets | `dotfiles/.sops.yaml` + `hosts/<host>/secrets.yaml` | copy shared Otto age private key out-of-band, let `sops-nix` decrypt at runtime |
| Identity docs | `hermes-brain/SOUL.md`, `BERKER.md`, `MAP.md`, wiki | clone/sync brain repo into `/home/hermes/.hermes` safe paths |
| Injected memory/profile | `hermes-brain/memories/MEMORY.md`, `hermes-brain/memories/USER.md` | restore to `/home/hermes/.hermes/memories/` before first real session |
| Skills | `hermes-brain/skills/` | restore to `/home/hermes/.hermes/skills/` |
| Wiki/RAG source docs | `hermes-brain/wiki/` | restore Markdown, rebuild vector index locally |
| Backlogs/reports/kanban | `hermes-brain/HERMES_TASKS.md`, reports, safe kanban JSON | restore from brain repo |
| Runtime/auth/session state | not GitHub-safe by default | re-auth or restore from a separate encrypted backup only if intentionally chosen |

Explicitly not GitHub-backed: plaintext `.env`, `auth.json`, sessions, logs, cron runtime output, platform runtime data, local DBs, vector cache, browser profiles/cookies, Tailscale machine state, private keys, tokens.

## 1. Current VPS pre-flight, before touching the new host

Run these on the current primary host. Do not print secret values.

```bash
# Confirm repos are clean or intentionally dirty.
HOME=/home/hermes git -C /home/hermes/dotfiles status --short --branch
HOME=/home/hermes git -C /home/hermes/hermes-brain-sync status --short --branch

# Push declarative config.
HOME=/home/hermes git -C /home/hermes/dotfiles fetch origin main
HOME=/home/hermes git -C /home/hermes/dotfiles add -A
HOME=/home/hermes git -C /home/hermes/dotfiles diff --cached --check
HOME=/home/hermes git -C /home/hermes/dotfiles commit -m "docs: add on-prem rebuild guide" || true
HOME=/home/hermes git -C /home/hermes/dotfiles push

# Trigger/verify brain sync.
# Preferred from Hermes: run cron job sync-hermes-brain-to-github.
# Manual fallback:
SRC=/home/hermes/.hermes/
DST=/home/hermes/hermes-brain-sync/
rsync -a --delete --filter='P .git/' --filter=':- /home/hermes/.hermes/.gitignore' --exclude='.git/' "$SRC" "$DST"
HOME=/home/hermes git -C "$DST" clean -fdX
HOME=/home/hermes git -C "$DST" add -A
HOME=/home/hermes git -C "$DST" commit -m "chore: sync brain snapshot" || true
HOME=/home/hermes git -C "$DST" push
```

Sanity checks:

```bash
# Memory/profile snapshots must be in the brain repo.
HOME=/home/hermes git -C /home/hermes/hermes-brain-sync ls-files \
  memories/MEMORY.md memories/USER.md SOUL.md BERKER.md MAP.md

# Vector/cache/runtime should not be tracked.
HOME=/home/hermes git -C /home/hermes/hermes-brain-sync ls-files \
  vector sessions logs cron auth.json config.yaml .env || true

# Encrypted secrets must look encrypted, not plaintext.
rg 'ENC\[' /home/hermes/dotfiles/hosts/*/secrets.yaml
rg 'AGE-SECRET-KEY|NOUS_API_KEY=|TELEGRAM_BOT_TOKEN=|GMAIL_APP_PASSWORD=' /home/hermes/dotfiles || true
```

Expected: the first command lists soul/memory files, vector/runtime checks produce no tracked files, `secrets.yaml` contains `ENC[` ciphertext, and no plaintext secret assignments appear in dotfiles.

## 2. Prepare the on-prem host entry in dotfiles

The current live flake target is `hermesbox` and is `aarch64-linux` for the Oracle VPS. The on-prem ThinkCentre-class box is likely `x86_64-linux`, so do not blindly reuse that target.

Before cutover, add a new host, for example `hosts/otto-onprem/`, and a matching flake output:

```nix
nixosConfigurations.otto-onprem = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit hermes-agent; };
  modules = [
    hermes-agent.nixosModules.default
    sops-nix.nixosModules.sops
    ./hosts/otto-onprem/configuration.nix
  ];
};
```

Copy/adapt from `hosts/hermesbox/`:

- `configuration.nix`
- `hermes-agent.nix`
- `himalaya.nix`
- `tailscale.nix`
- `sops-secrets.nix`
- `hermes-cron-jobs.json`
- `scripts/`
- new `hardware-configuration.nix` generated on the physical host
- `secrets.yaml`, either reuse the current encrypted values with the shared recipient or create a host-specific encrypted file with the same keys

Keep `networking.hostName` distinct, for example `otto-onprem`, until final cutover. This lets the VPS stay alive as fallback.

## 3. Install NixOS on the on-prem machine

On the installer/live environment:

```bash
# Example only: partitioning is hardware-specific. After disks are mounted:
nixos-generate-config --root /mnt

# Ensure flakes are available for the first build if the installer is minimal.
mkdir -p /mnt/etc/nixos
```

Create a temporary minimal config if needed only to get SSH and git working. The durable config must come from `/home/hermes/dotfiles`, not hand-edited `/etc` drift.

## 4. Create the hermes user and clone dotfiles

After first boot or from a prepared installer environment, make sure the target has the `hermes` user. If using the flake from the start, the user is declared there. If bootstrapping imperatively, treat this as temporary:

```bash
sudo useradd -m -s /run/current-system/sw/bin/bash hermes || true
sudo mkdir -p /home/hermes
sudo chown hermes:hermes /home/hermes

sudo -u hermes HOME=/home/hermes git clone https://github.com/otto-hermes/dotfiles.git /home/hermes/dotfiles
```

If pushing from the new host is needed, configure GitHub auth for the `hermes` user later. For restore, clone/fetch is enough if the repos are public/readable from the host.

## 5. Install the shared Otto age key, out of band

Berker keeps the shared Otto age private key outside GitHub. Copy it to the new host via a private channel, never chat, never git, never logs.

Expected path for the current simple strategy:

```bash
sudo install -d -m 0700 -o hermes -g hermes /home/hermes/.keys
sudo install -m 0600 -o hermes -g hermes sops-age-otto-shared.txt /home/hermes/.keys/sops-age-otto-shared.txt
sudo stat -c '%A %U:%G %n' /home/hermes/.keys /home/hermes/.keys/sops-age-otto-shared.txt
```

Expected modes:

```text
drwx------ hermes:hermes /home/hermes/.keys
-rw------- hermes:hermes /home/hermes/.keys/sops-age-otto-shared.txt
```

Do not run `cat` or `sops -d` into terminal transcripts unless absolutely necessary. Verify with file metadata and `ENC[` checks.

## 6. Build and switch the on-prem flake

From the new host:

```bash
cd /home/hermes/dotfiles

# Build first. Replace otto-onprem with the actual new flake target.
sudo nixos-rebuild build --flake /home/hermes/dotfiles#otto-onprem

# Switch only after build succeeds.
sudo nixos-rebuild switch --flake /home/hermes/dotfiles#otto-onprem
```

If the target is still named `hermesbox`, fix the flake/host naming before final cutover. Separate names reduce accidental VPS/on-prem confusion.

Verify activation:

```bash
readlink -f /run/current-system
hostnamectl hostname
systemctl is-active hermes-agent.service hermes-dashboard.service tailscaled.service || true
systemctl cat hermes-agent.service | grep -E 'HERMES_HOME|EnvironmentFile|/run/secrets|SHELL'
for p in /run/secrets /home/hermes/.keys/sops-age-otto-shared.txt /home/hermes/.hermes; do
  [ -e "$p" ] && stat -c '%A %U:%G %s %n' "$p" || echo "missing $p"
done
```

## 7. Restore the safe Otto brain from GitHub

Stop Hermes while restoring so it does not create partial first-run state.

```bash
sudo systemctl stop hermes-agent.service hermes-dashboard.service || true

sudo -u hermes HOME=/home/hermes git clone https://github.com/otto-hermes/hermes-brain.git /home/hermes/hermes-brain-sync
sudo -u hermes HOME=/home/hermes mkdir -p /home/hermes/.hermes

# Restore safe mirrored content into the runtime Hermes home.
# The brain repo already excludes secrets/runtime state.
sudo -u hermes HOME=/home/hermes rsync -a --delete \
  --exclude='.git/' \
  /home/hermes/hermes-brain-sync/ /home/hermes/.hermes/

sudo chown -R hermes:hermes /home/hermes/.hermes /home/hermes/hermes-brain-sync
```

Critical restore checks:

```bash
for p in \
  /home/hermes/.hermes/SOUL.md \
  /home/hermes/.hermes/BERKER.md \
  /home/hermes/.hermes/MAP.md \
  /home/hermes/.hermes/memories/MEMORY.md \
  /home/hermes/.hermes/memories/USER.md \
  /home/hermes/.hermes/skills \
  /home/hermes/.hermes/wiki; do
  [ -e "$p" ] && stat -c '%A %U:%G %s %n' "$p" || echo "MISSING $p"
done

# These should not exist from the public brain restore unless intentionally restored separately.
for p in /home/hermes/.hermes/auth.json /home/hermes/.hermes/config.yaml /home/hermes/.hermes/.env /home/hermes/.hermes/sessions /home/hermes/.hermes/logs; do
  [ ! -e "$p" ] && echo "ok absent $p" || echo "CHECK unexpected runtime path $p"
done
```

If `SOUL.md`, `BERKER.md`, `memories/MEMORY.md`, or `memories/USER.md` are missing, do not start a real session. Fix the brain sync first.

## 8. Rebuild local derived indexes/caches

The vector DB is deliberately not GitHub-backed. Rebuild it from wiki/docs after restoring Markdown:

```bash
sudo -u hermes HOME=/home/hermes /home/hermes/.hermes/scripts/wiki-index.py || true
sudo -u hermes HOME=/home/hermes /home/hermes/.hermes/scripts/wiki-query.py "Otto soul" || true
```

If the scripts are missing, the brain restore is incomplete or the script generation activation has not run. Re-run the NixOS switch and inspect `/home/hermes/.hermes/scripts`.

## 9. Restore or re-auth sensitive runtime state deliberately

Default recommendation: re-auth rather than copying opaque token/cookie state.
auth.json is intentionally not GitHub-backed. Do not copy it from the old host.

Re-auth/check list (run as hermes user):

```bash
# 1. Check current provider status
sudo -u hermes HOME=/home/hermes hermes status --all
sudo -u hermes HOME=/home/hermes hermes auth list

# 2. Nous OAuth (interactive — opens a browser device-code URL)
sudo -u hermes HOME=/home/hermes hermes login --provider nous
#   Follow the printed URL, complete the device code flow in a browser.

# 3. OpenAI Codex OAuth (interactive — same device-code flow)
sudo -u hermes HOME=/home/hermes hermes login --provider openai-codex

# 4. Verify credential pools populated
sudo -u hermes HOME=/home/hermes hermes auth list
#   Expected pools: nous (oauth), openai-codex (oauth), openrouter (api_key,
#   auto-sourced from env:OPENROUTER_API_KEY in .env), copilot (api_key,
#   auto-sourced from env:GITHUB_TOKEN in .env)

# 5. Email
sudo -u hermes HOME=/home/hermes himalaya account list

# 6. Tailscale
tailscale status
```

Providers that restore automatically from sops-decrypted `.env` (no manual step):
- **OpenRouter** — `OPENROUTER_API_KEY` is in sops `/run/secrets/hermes.env`
- **GitHub Copilot** — `GITHUB_TOKEN` is in sops `/run/secrets/hermes.env`

Providers that need interactive OAuth on every fresh machine:
- **Nous** — `hermes login --provider nous` (device code, browser required)
- **OpenAI Codex** — `hermes login --provider openai-codex` (device code, browser required)

Sensitive state that may need explicit handling:

- `auth.json`: contains OAuth tokens with expiry (nous access ~15min, auto-refreshes)
- Messaging platform pairing/home-channel state: verify Telegram/Discord/etc. after gateway starts.
- Sessions: do not restore wholesale unless Berker explicitly wants transcript history on the new box. Session recall can be summarized into wiki instead.
- Browser/cookies: re-login if browser automation needs it.
- Tailscale: use `sops-nix` auth key/bootstrap; do not copy machine state by default.

If a separate encrypted tarball backup is used, extract only the intended files, then immediately check modes and ownership. Never put that tarball in GitHub unless encrypted and intentionally designed for backup.

## 10. Start services and validate capability by capability

```bash
sudo systemctl daemon-reload
sudo systemctl restart hermes-agent.service hermes-dashboard.service
sudo systemctl status --no-pager hermes-agent.service hermes-dashboard.service
journalctl -u hermes-agent.service -u hermes-dashboard.service -b --no-pager -n 120
```

Validation checklist:

1. Hermes CLI works:
   ```bash
   sudo -u hermes HOME=/home/hermes hermes --version
   sudo -u hermes HOME=/home/hermes hermes status --all
   ```
2. Memory/profile loaded: start a test chat and ask for a non-secret self-check, for example "summarize your current MAP/SOUL/memory sources". Confirm it references `/home/hermes/.hermes`, Otto, Berker, skills, and wiki.
3. Gateway receives a message from Berker and replies in the expected tone.
4. Dashboard binds to the Tailscale IP on port `9119`:
   ```bash
   tailscale ip -4
   ss -ltnp | grep 9119 || true
   ```
5. Email works:
   ```bash
   sudo -u hermes HOME=/home/hermes himalaya account list
   ```
   Then send a small test email only after account listing succeeds.
6. GitHub push works as `hermes`:
   ```bash
   sudo -u hermes HOME=/home/hermes git -C /home/hermes/dotfiles status --short --branch
   sudo -u hermes HOME=/home/hermes git -C /home/hermes/hermes-brain-sync status --short --branch
   ```
7. Cron jobs are present:
   ```bash
   sudo -u hermes HOME=/home/hermes hermes cron list --all
   systemctl status --no-pager hermes-cron-sync.service hermes-cron-sync.timer || true
   ```
8. No secrets are tracked:
   ```bash
   HOME=/home/hermes git -C /home/hermes/dotfiles status --short
   HOME=/home/hermes git -C /home/hermes/hermes-brain-sync status --short
   HOME=/home/hermes git -C /home/hermes/hermes-brain-sync ls-files auth.json config.yaml .env sessions logs cron vector || true
   ```

## 11. Cutover procedure

Only cut over after every validation above passes.

1. Leave the VPS running but pause user-facing ingress there if duplicate replies are possible.
2. Point Telegram/Discord/webhook/home integrations to the on-prem gateway if needed.
3. Confirm a real Berker message reaches the on-prem host.
4. Trigger brain and dotfiles sync from the on-prem host.
5. Keep the VPS untouched for several days as rollback.
6. After confidence window, archive the VPS state or destroy it only after Berker approves.

Rollback is simple while the VPS remains alive: stop on-prem gateway/services, resume VPS gateway/services, and use the last GitHub brain/dotfiles commits as the reconciliation point.

## 12. Personality/data-loss guardrails

Do not start using the new node as primary unless all of these are true:

```bash
test -s /home/hermes/.hermes/SOUL.md
test -s /home/hermes/.hermes/BERKER.md
test -s /home/hermes/.hermes/MAP.md
test -s /home/hermes/.hermes/memories/MEMORY.md
test -s /home/hermes/.hermes/memories/USER.md
test -d /home/hermes/.hermes/skills
test -d /home/hermes/.hermes/wiki
sudo -u hermes HOME=/home/hermes hermes status --all
```

If any test fails, stop. Do not paper over it with fresh memory. Restore from `otto-hermes/hermes-brain` or the old VPS first.

## 13. Disaster recovery from only GitHub + Berker's key

Minimum viable restore if the VPS is gone:

1. Install NixOS.
2. Clone `https://github.com/otto-hermes/dotfiles` to `/home/hermes/dotfiles`.
3. Copy Berker's shared Otto age private key to `/home/hermes/.keys/sops-age-otto-shared.txt` with `0600 hermes:hermes`.
4. `sudo nixos-rebuild switch --flake /home/hermes/dotfiles#otto-onprem`.
5. Clone `https://github.com/otto-hermes/hermes-brain` to `/home/hermes/hermes-brain-sync`.
6. `rsync -a --exclude='.git/' /home/hermes/hermes-brain-sync/ /home/hermes/.hermes/`.
7. Rebuild the wiki/vector index.
8. Re-auth providers/platforms that are intentionally not GitHub-backed.
9. Run the validation checklist.

This restores Otto's personality, skills, docs, memory snapshots, and declarative operating environment. It does not restore raw sessions/logs/OAuth caches unless a separate encrypted backup exists.

## 14. Future improvement checklist

These reduce migration risk further before final on-prem move:

- Add `hosts/otto-onprem/` as an explicit `x86_64-linux` target.
- Make `README-bootstrap.md` part of every dotfiles sync check.
- Add a deterministic restore smoke-test script that checks required files and absent runtime paths.
- Decide whether `auth.json` needs encrypted backup or deliberate re-auth is enough.
- Decide whether sessions should remain excluded forever or whether sanitized summaries are sufficient.
- Run one full rehearsal on a throwaway VM before physical cutover.
