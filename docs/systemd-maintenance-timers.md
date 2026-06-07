# Handoff: systemd-owned NixOS maintenance

We moved daily NixOS host maintenance off Hermes cron and into systemd.

## Decision

The daily flake update and rebuild are now owned by:

- `hermes-daily-nixos-rebuild.timer`
- `hermes-daily-nixos-rebuild.service`
- `hermes-daily-nixos-rebuild-notify.service`

Hermes cron no longer schedules this host-level task. The previous Hermes cron job `daily-dotfiles-nixos-rebuild` is paused, and its old wrapper script is removed from `/home/hermes/.hermes/scripts`.

## Why

NixOS rebuilds are root-level host maintenance. They mutate the system generation, systemd units, `/etc`, and `/nix/store`. Scheduling them through Hermes cron forced an awkward chain:

Hermes cron -> Python wrapper -> sudo path handling -> systemd unit -> nixos-rebuild

That made failure reporting and ownership muddy. Hermes cron could report success after merely queueing the systemd unit, even if the rebuild failed later. It also meant host maintenance depended on Hermes cron staying healthy.

The new design keeps the host control plane in systemd. Hermes can observe/report host state, but it does not own the schedule.

## Telegram reporting

Failure reporting is preserved without putting scheduling back under Hermes. If `hermes-daily-nixos-rebuild.service` fails, systemd triggers `hermes-daily-nixos-rebuild-notify.service`, which sends a Telegram message to the configured home channel using:

- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_HOME_CHANNEL`

Both are sourced at runtime from `/home/hermes/.keys/hermes.env` or `/home/hermes/.hermes/.env`. Secrets are not written into the Nix store.

Success is intentionally quiet, matching the old silent-on-clean-run pattern.

## Commands

Check schedule:

```bash
systemctl list-timers hermes-daily-nixos-rebuild.timer --no-pager
```

Run maintenance manually:

```bash
sudo systemctl start hermes-daily-nixos-rebuild.service
```

Read logs:

```bash
journalctl -u hermes-daily-nixos-rebuild.service -n 160 --no-pager
```

Check alert hook:

```bash
systemctl cat hermes-daily-nixos-rebuild-notify.service --no-pager
```

## Rule of thumb

Use systemd timers for host maintenance: NixOS rebuilds, service restarts, firewall/Tailscale/system package changes, root-owned secrets activation, and anything that mutates `/etc`, `/nix/store`, or system units.

Use Hermes cron for Hermes/app work: reports, wiki or memory tasks, sync jobs, and work that only needs the `hermes` user state.
