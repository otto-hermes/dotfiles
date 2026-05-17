# Otto / hermesbox dotfiles

Declarative NixOS configuration for Otto's Hermes Agent hosts.

Current live target:

- `hermesbox`: Oracle Cloud VPS, `aarch64-linux`

Next intended target:

- on-prem Otto node, likely `x86_64-linux`, to be added as a separate host target before cutover

## Critical restore docs

- [`README-bootstrap.md`](./README-bootstrap.md) is the step-by-step on-prem rebuild and migration guide. Keep it current before any physical-host cutover.

## Design docs

- [`docs/route-task-interface.md`](./docs/route-task-interface.md) recommends a first-class `route_task` Hermes tool interface for default-profile delegation without broad terminal access.

## Rebuild current VPS

```bash
sudo nixos-rebuild switch --flake /home/hermes/dotfiles#hermesbox
```

## Hermes specialist profiles

`hosts/hermesbox/hermes-profiles.nix` is the source of truth for specialist
Hermes profiles, their routing metadata, and their executable wrappers. Runtime
files under `/home/hermes/.hermes/profiles/<profile>/` are generated state; do
not hand-edit them as the long-term fix.

Expected Nix-managed wrapper commands on `hermesbox`:

- `worker` — cheap/read-mostly local inspection profile.
- `coding` — project coding, tests, repo, GitHub, and PR profile.
- `setup-worker` — NixOS/dotfiles/Hermes machine setup and declarative config profile.
- `planner` — implementation planning and task decomposition profile.
- `research-worker` — web/current-facts research profile.
- `productivity-worker` — email/docs/calendar/reporting profile.
- `media-worker` — image/video/audio/creative profile.
- `knowledge-curator` — wiki, memory, session, and note curation profile.
- `session-indexer` — scheduled session indexing/summarization profile.
- `wiki-linter` — scheduled Otto wiki linting profile.
- `fallback-full` — last-resort broad tool/profile fallback.
- `hermes-profile-router` — routes task text using generated `PROFILE.md`
  frontmatter.

Wrapper lifecycle:

1. Edit profile settings, route metadata, or wrapper generation in
   `hosts/hermesbox/hermes-profiles.nix`.
2. Rebuild with `sudo nixos-rebuild switch --flake /home/hermes/dotfiles#hermesbox`.
3. Nix exposes wrappers from `/run/current-system/sw/bin`, which is already on
   the operator/service PATH. The wrappers are not installed in
   `/home/hermes/.local/bin`; stale files there should not be treated as source
   of truth.
4. Activation regenerates `/home/hermes/.hermes/profiles/<profile>/config.yaml`,
   `PROFILE.md`, and `SOUL.md` from Nix. `PROFILE.md` frontmatter must keep
   routing hints (`summary`, `tags`, `use_for`, `avoid_for`, `priority`,
   `fallback`) because `hermes-profile-router` reads those fields dynamically.

Recovery/audit commands:

```bash
command -v coding setup-worker hermes-profile-router
head -20 /run/current-system/sw/bin/coding
head -20 /run/current-system/sw/bin/setup-worker
hermes-profile-router list
sudo nixos-rebuild build --flake /home/hermes/dotfiles#hermesbox
sudo nixos-rebuild switch --flake /home/hermes/dotfiles#hermesbox
```

If the switch is launched from a hardened Hermes service/session and fails with
`/nix/var/nix/profiles/... Read-only file system`, trigger the switch through
the host systemd manager so the rebuild runs outside the service mount namespace:

```bash
sudo systemd-run --unit=hermes-manual-profile-switch --wait --collect \
  --property=WorkingDirectory=/home/hermes/dotfiles --setenv=HOME=/root \
  /run/current-system/sw/bin/bash -lc \
  'git config --global --add safe.directory /home/hermes/dotfiles; exec /run/current-system/sw/bin/nixos-rebuild switch --flake /home/hermes/dotfiles#hermesbox'
```

Then inspect `sudo journalctl -u hermes-manual-profile-switch.service -n 120 --no-pager -o cat`.
