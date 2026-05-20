     1|# Otto / hermesbox dotfiles
     2|
     3|Declarative NixOS configuration for Otto's Hermes Agent hosts.
     4|
     5|Current live target:
     6|
     7|- `hermesbox`: Oracle Cloud VPS, `aarch64-linux`
     8|
     9|Next intended target:
    10|
    11|- on-prem Otto node, likely `x86_64-linux`, to be added as a separate host target before cutover
    12|
    13|## Critical restore docs
    14|
    15|- [`README-bootstrap.md`](./README-bootstrap.md) is the step-by-step on-prem rebuild and migration guide. Keep it current before any physical-host cutover.
    16|
    17|## Design docs
    18|
    20|- [`docs/profile-routing-token-usage.md`](./docs/profile-routing-token-usage.md) records the routing/token/cache audit, current policy, and follow-up checklist.
    21|
    22|## Rebuild current VPS
    23|
    24|```bash
    25|sudo nixos-rebuild switch --flake /home/hermes/dotfiles#hermesbox
    26|```
    27|
    29|
    31|Hermes profiles, their routing metadata, and their executable wrappers. Runtime
    32|files under `/home/hermes/.hermes/profiles/<profile>/` are generated state; do
    33|not hand-edit them as the long-term fix.
    34|
    35|Expected Nix-managed wrapper commands on `hermesbox`:
    36|
    37|- `worker` — cheap/read-mostly local inspection profile.
    38|- `coding` — project coding, tests, repo, GitHub, and PR profile.
    39|- `setup-worker` — NixOS/dotfiles/Hermes machine setup and declarative config profile.
    40|- `planner` — implementation planning and task decomposition profile.
    41|- `research-worker` — web/current-facts research profile.
    42|- `productivity-worker` — email/docs/calendar/reporting profile.
    43|- `media-worker` — image/video/audio/creative profile.
    44|- `knowledge-curator` — wiki, memory, session, and note curation profile.
    45|- `session-indexer` — scheduled session indexing/summarization profile.
    46|- `wiki-linter` — scheduled Otto wiki linting profile.
    47|- `fallback-full` — last-resort broad tool/profile fallback.
    49|  frontmatter.
    50|
    51|Wrapper lifecycle:
    52|
    53|1. Edit profile settings, route metadata, or wrapper generation in
    55|2. Rebuild with `sudo nixos-rebuild switch --flake /home/hermes/dotfiles#hermesbox`.
    56|3. Nix exposes wrappers from `/run/current-system/sw/bin`, which is already on
    57|   the operator/service PATH. The wrappers are not installed in
    58|   `/home/hermes/.local/bin`; stale files there should not be treated as source
    59|   of truth.
    60|4. Activation regenerates `/home/hermes/.hermes/profiles/<profile>/config.yaml`,
    61|   `PROFILE.md`, and `SOUL.md` from Nix. `PROFILE.md` frontmatter must keep
    62|   routing hints (`summary`, `tags`, `use_for`, `avoid_for`, `priority`,
    64|
    65|Recovery/audit commands:
    66|
    67|```bash
    69|head -20 /run/current-system/sw/bin/coding
    70|head -20 /run/current-system/sw/bin/setup-worker
    72|sudo nixos-rebuild build --flake /home/hermes/dotfiles#hermesbox
    73|sudo nixos-rebuild switch --flake /home/hermes/dotfiles#hermesbox
    74|```
    75|
    76|If the switch is launched from a hardened Hermes service/session and fails with
    77|`/nix/var/nix/profiles/... Read-only file system`, trigger the switch through
    78|the host systemd manager so the rebuild runs outside the service mount namespace:
    79|
    80|```bash
    81|sudo systemd-run --unit=hermes-manual-profile-switch --wait --collect \
    82|  --property=WorkingDirectory=/home/hermes/dotfiles --setenv=HOME=/root \
    83|  /run/current-system/sw/bin/bash -lc \
    84|  'git config --global --add safe.directory /home/hermes/dotfiles; exec /run/current-system/sw/bin/nixos-rebuild switch --flake /home/hermes/dotfiles#hermesbox'
    85|```
    86|
    87|Then inspect `sudo journalctl -u hermes-manual-profile-switch.service -n 120 --no-pager -o cat`.
    88|