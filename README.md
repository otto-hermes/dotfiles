# Otto / hermesbox dotfiles

Declarative NixOS configuration for Otto's Hermes Agent hosts.

Current live target:

- `hermesbox`: Oracle Cloud VPS, `aarch64-linux`

Next intended target:

- on-prem Otto node, likely `x86_64-linux`, to be added as a separate host target before cutover

## Critical restore docs

- [`README-bootstrap.md`](./README-bootstrap.md) is the step-by-step on-prem rebuild and migration guide. Keep it current before any physical-host cutover.

## Rebuild current VPS

```bash
sudo nixos-rebuild switch --flake /home/hermes/dotfiles#hermesbox
```
