# First-class `route_task` interface for the default profile

Status: implemented locally on hermesbox. Keep this as the design contract for the Nix-managed routing plugin and CLI fallback.

## Problem

The current profile routing work gives Hermes a declarative set of specialist profiles and a working `hermes-profile-router` CLI, but the default profile still needs a narrow way to ask for specialist execution. If the only usable interface is broad `terminal` access plus a shell command, then the default profile remains overprivileged and routing depends on prompt discipline instead of a first-class capability boundary.

The missing interface is not better scoring. The existing router already has useful `choose`, `plan`, and `launch` behavior. The missing piece is a small Hermes tool that exposes those behaviors without exposing arbitrary shell execution.

## Existing state reviewed

Current declarative routing pieces live in:

- `hosts/hermesbox/hermes-profiles.nix`
  - declares specialist profile configs, toolsets, memory/compression settings, generated `PROFILE.md` metadata, generated `SOUL.md`, profile wrapper commands, and the `hermes-profile-router` package.
- `hosts/hermesbox/scripts/hermes-profile-router.py`
  - reads generated `~/.hermes/profiles/*/PROFILE.md` frontmatter.
  - supports `list`, `choose`, `command`, `plan`, `execute-plan`, and `launch`.
  - contains guardrail routing for planning, coding/Nix/Hermes config, knowledge/wiki/session work, research, productivity, media, and cheap local checks.
  - supports conditional plans: a cheap `worker` check first, then a specialist create step only if missing.
- `hosts/hermesbox/scripts/tests/test_hermes_profile_router.py`
  - covers atomic routing, conditional routing, scheduled wiki/session routing, fallback routing, planner routing, and chat-only default behavior.

Prior routing work found the tool gap: the default profile can reason that another profile should do the work, and the CLI can launch that profile, but there is no narrow toolset capability equivalent to "route this task". The fallback is terminal invocation, which is too broad for a chat/router default profile.

## Options comparison

| Option | Shape | Pros | Cons | Security result | Verdict |
|---|---|---|---|---|---|
| Existing terminal CLI wrapper | Default profile calls `hermes-profile-router choose/plan/launch` through `terminal`. | Already exists, declarative Nix package, easy to test, preserves current router code. | Requires `terminal` in default profile; any command could be run, not just routing; shell quoting and cwd/env become part of the trust boundary. | Does not remove broad terminal access. It only narrows behavior by convention. | Keep as low-level implementation/debug interface, not the default profile interface. |
| Hermes toolset tool | Add a `route_task` tool in Hermes that calls the router library/subprocess with a fixed schema and allowlisted actions. | First-class capability; no arbitrary shell; can validate args and profiles; good model ergonomics; fits Hermes tool architecture; easy to enable only on default. | Requires small upstream/local Hermes code, tool schema, tests, and packaging. Needs care to avoid recursive self-routing. | Removes need for broad terminal on default; exposes only choose/plan/launch semantics. | Recommended. |
| Gateway-side route action | Teach Telegram/Discord/API gateway to route incoming tasks before selecting a profile/session. | Good for platform-level routing; can keep default profile out of the loop entirely. | Gateway-specific; less useful from CLI/TUI; mixes delivery/session concerns with task planning; harder to invoke during a conversation. | Can be secure, but only at gateway edge. Does not provide an in-session delegation primitive. | Later enhancement, not minimal core fix. |
| Cron/kanban handoff | Default creates a kanban/cron item assigned to a specialist. | Durable, auditable, good for long-running or reviewed work; already has cross-agent lifecycle. | Heavyweight for ordinary one-shot delegation; async semantics; creates board noise; not ideal for "answer this now via specialist". | Narrow if default only has kanban-create, but changes UX and requires board machinery for every delegation. | Use for durable/reviewed work, not as the primary interactive route interface. |
| Profile-router launch wrapper | Add wrapper commands per profile or a `route` launcher around `hermes --profile ...`. | Simple Nix packaging; useful for humans and scripts; no Hermes core changes if used manually. | Still command execution; if exposed to the model through terminal, it has the same broad-tool problem. | Better reproducibility than ad hoc shell, but not a capability boundary. | Keep for operator/debug ergonomics, not default model access. |

## Recommended minimal architecture

Implement a first-class Hermes toolset named `routing` with one tool: `route_task`.

Tool schema:

```json
{
  "name": "route_task",
  "description": "Choose, plan, or launch a Hermes specialist profile for a task using declarative profile metadata.",
  "parameters": {
    "type": "object",
    "properties": {
      "action": {"type": "string", "enum": ["choose", "plan", "launch"]},
      "task": {"type": "string", "minLength": 1},
      "profile": {"type": "string", "description": "Optional explicit profile override for launch; must be allowlisted."},
      "mode": {"type": "string", "enum": ["foreground", "background"], "default": "foreground"},
      "max_confidence_floor": {"type": "number", "default": 0.35}
    },
    "required": ["action", "task"]
  }
}
```

Semantics:

1. `choose`
   - Loads generated profile metadata.
   - Returns the same decision shape as the CLI: `profile`, `confidence`, `score`, `margin`, `reason`, `candidates`.
   - No subprocess launch.
2. `plan`
   - Returns the router plan: `strategy`, `reason`, `fallback_profile`, `steps`, and embedded `chosen_by` decisions.
   - No subprocess launch.
3. `launch`
   - Computes a plan or uses an explicit allowlisted `profile` override.
   - Starts `hermes --profile <specialist> chat -q <bounded prompt>` without going through a shell.
   - For foreground: returns specialist stdout/stderr, exit status, selected profile, and plan metadata.
   - For background: returns pid/job handle and log path under `~/.hermes/logs/profile-router/`.
   - Refuses to launch `default` unless the action was only `choose`/`plan`; default should not recursively launch itself.

Implementation should reuse the existing router logic rather than fork behavior:

- Preferred: move `hermes-profile-router.py` into importable Python functions under Hermes or a small local module, keeping the CLI as a thin wrapper.
- Acceptable minimal local step: the Hermes tool invokes the existing script by absolute Nix store path with `subprocess.run([...], shell=False)`, not through terminal, and parses JSON. This still avoids arbitrary shell access but is less clean than an importable module.

## Security properties

The default profile should get `routing`, not `terminal`, for specialist delegation.

Security boundary:

- Allowed operation is only `choose`, `plan`, or `launch` with a task string.
- No shell interpolation. Use argv lists or direct Python imports.
- Profile names come from generated `PROFILE.md` metadata and/or a declarative allowlist.
- `default`, archived/disabled profiles, and profiles without valid config are refused for `launch`.
- Tool output redacts or avoids secrets by returning handles/log paths and concise summaries, not raw env.
- Background logs are written under a fixed Hermes-owned directory.
- Low-confidence routes do not silently launch a powerful fallback unless policy explicitly allows it.

Can broad terminal access be removed from default?

Yes for routing. The default profile only needs normal conversational tools plus `routing` to select/plan/launch specialists. It does not need broad `terminal` merely to run `hermes-profile-router`. Specialist profiles keep the toolsets they need for execution. If default still needs terminal for unrelated reasons, that should be justified separately; it should not be justified by routing.

Recommended launch policy:

- `confidence >= 0.70`: launch allowed.
- `0.35 <= confidence < 0.70`: return plan and ask the user or default profile to choose; do not launch automatically unless the request explicitly named a profile.
- `< 0.35`: return candidates and `low_confidence`; do not launch fallback automatically from default.

This is stricter than the CLI fallback behavior because a first-class tool is a privilege boundary, not just a convenience command.

## Toolset implications

Default profile:

- Enable `routing`.
- Keep `terminal` disabled if routing is the only reason it was enabled.
- Keep lightweight chat/context tools as desired: `skills`, `memory`, `session_search`, `clarify`, `todo`.
- Do not enable specialist-heavy tools on default just because specialists have them.

Specialist profiles:

- No need for `routing` by default. They should execute within their domain, not recursively orchestrate, unless a specific profile is intentionally an orchestrator/planner.
- Keep existing declared toolsets:
  - `worker`: cheap/read-mostly local inspection.
  - `coding`: project code, tests, repos, GitHub, PRs.
  - `setup-worker`: NixOS, dotfiles, Hermes config/profiles/router/toolsets/providers, services, cronjobs, Tailscale, host behavior.
  - `planner`: architecture and decomposition.
  - `research-worker`: web/current facts.
  - `productivity-worker`: email/docs/calendar/reporting.
  - `media-worker`: vision/image/video/audio/creative workflows.
  - `knowledge-curator`, `session-indexer`, `wiki-linter`: wiki/session/memory maintenance.
  - `fallback-full`: last-resort execution, but not auto-launched on low confidence by default.

## NixOS declarative/reproducible path

All durable pieces must live in `/home/hermes/dotfiles`, not generated runtime files.

Recommended declarative path:

1. Keep profile definitions and routing metadata in `hosts/hermesbox/hermes-profiles.nix`.
2. Package the router implementation with Nix, as today, so the tool calls a stable store path or imports a source path managed by the flake.
3. Add the `routing` toolset enablement to the default profile config in Nix, not by editing `~/.hermes/profiles/default/config.yaml`.
4. Keep generated `PROFILE.md` frontmatter as the source consumed by the router, but generate it from Nix declarations.
5. Add tests beside the router tests and/or Hermes tool tests.
6. Verify with:
   - router unit tests: `python -m pytest hosts/hermesbox/scripts/tests/test_hermes_profile_router.py -q`
   - tool tests once implemented: targeted Hermes tool tests
   - Nix validation: `nix flake check`
   - deployment after review: `sudo nixos-rebuild switch --flake /home/hermes/dotfiles#hermesbox`

## Failure modes

Missing specialist profile:

- `choose`/`plan`: return `profile_missing` if the chosen profile is not present in generated metadata/config; include candidates and fallback policy.
- `launch`: hard fail before subprocess start. Do not silently substitute `fallback-full` unless the plan explicitly says fallback and confidence policy allows it.
- Operator fix: add or restore the profile declaration in `hosts/hermesbox/hermes-profiles.nix`, rebuild, and verify generated `~/.hermes/profiles/<name>/PROFILE.md`.

Broken auth or model/provider failure:

- `launch`: return `launch_failed` with exit status, selected profile, provider/model if known, and concise stderr tail.
- Do not retry on a different profile automatically; auth is usually profile/provider-specific and silent fallback can cause cost/security surprises.
- Operator fix: inspect `~/.hermes/auth.json`, credential pool/provider config, and profile `config.yaml`; run `hermes doctor` or provider login flow as appropriate.

Low routing confidence:

- `choose`: return candidates and confidence.
- `plan`: return `needs_clarification` or `low_confidence` metadata.
- `launch`: refuse automatic launch below the configured floor unless the user explicitly named an allowlisted profile.
- Default-profile UX: ask one concise clarification or present top candidates. Do not launch `fallback-full` automatically for ambiguous user requests.

Router metadata missing/corrupt:

- Return `metadata_unavailable` with path checked and parse error.
- Do not launch.
- Operator fix: rebuild generated profile metadata from Nix activation.

Recursive/default launch:

- Refuse `launch` when selected profile is `default`.
- Return `stays_on_default` for chat-only/opinion requests.

## Minimal implementation plan if promoted

1. Refactor router script just enough that `choose`, `plan`, and launch command construction are importable and testable without argparse.
2. Add Hermes tool `route_task` in the tool registry under a new `routing` toolset.
3. Implement `choose` and `plan` as pure calls returning JSON-serializable dicts.
4. Implement `launch` using `subprocess.run`/`Popen` with argv lists, fixed env, timeout, log path, no shell.
5. Add confidence/profile allowlist checks before launch.
6. Add tests for:
   - `choose` returns expected specialist and candidates.
   - `plan` returns atomic and conditional steps.
   - `launch` builds/runs the expected profile command without shell.
   - missing profile refusal.
   - broken subprocess/auth failure shape.
   - low-confidence launch refusal.
   - default recursive launch refusal.
7. Add Nix profile config enabling `routing` for default and removing `terminal` from default if no other default use remains.
8. Update docs/README with the operator-facing routing behavior.

## Final recommendation

Build the Hermes `routing` toolset with one `route_task` tool, backed by the existing declarative profile metadata and router logic. Keep the CLI wrapper for humans/tests/debugging, but do not make the default profile use terminal as its delegation interface. This is the smallest architecture that turns routing into a real capability boundary, keeps specialist execution reproducible through Nix-managed profiles, and lets broad terminal access be removed or avoided for the default profile.
