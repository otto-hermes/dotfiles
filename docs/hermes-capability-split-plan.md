# Hermes Tool and Skill Lazy-Loading Split Plan

Generated: 2026-05-21T09:57:14

## Purpose

Design a safer Hermes capability layout that starts normal sessions with a small core tool surface, then routes into domain manifests/profiles such as media creation, home assistance, gaming, coding, research, and full remote operations. The goal is measurable token/cost reduction without deleting functionality. This is a planning/report document only: it does not change live userspace or Hermes runtime behavior.

Source material used for this report:

- Current live Hermes config/tool discovery via `hermes tools list` and Hermes Python internals.
- Current installed local skills under `/home/hermes/.hermes/skills`.
- Baseline measurement in `docs/hermes-prompt-budget-baseline.md`.
- Current dotfiles source of truth: `/home/hermes/dotfiles/hosts/hermesbox/hermes-agent.nix`.

## Current measured baseline

| Entrypoint | Configured toolsets | Loaded tool schemas | Pre-user baseline tokens | Tool schema tokens | Estimated input cost/request |
|---|---:|---:|---:|---:|---:|
| CLI | 28 | 33 | 18,346 | 11,953 | $0.009173 at $0.50/M |
| Telegram | 29 | 33 | 18,430 | 11,953 | $0.009215 at $0.50/M |
| Cron | 29 | 33 | 18,311 | 11,953 | $0.009156 at $0.50/M |

The important part: the tool schemas alone are about 11,953 tokens, roughly 65% of CLI baseline before the user message. This is the most concrete cost/latency lever.

At the pricing proxy used in the baseline (`$0.50 / 1M input tokens`), every 1,000 tokens removed from every request saves about `$0.0005/request`, `$0.50 per 1,000 requests`, or `$5 per 10,000 requests`. The money is not the only benefit: smaller tool surfaces also reduce latency, context pressure, and accidental affordance confusion.

## Definitions

- **Tool**: an actual callable function schema sent to the model, for example `terminal`, `read_file`, or `cronjob`.
- **Toolset**: a named group of tools, for example `file`, `browser`, `skills`, or `cronjob`.
- **Skill**: a markdown procedure or domain knowledge bundle. Skills are not all loaded in full by default, but the global skill catalog and skill-use instructions influence prompt size and task routing. Skills also tell us which domain manifests we should support.
- **Manifest/profile**: a proposed domain bundle containing toolsets, relevant skills, routing triggers, fallback policy, and verification expectations.
- **Lazy loading**: do not expose every tool schema at initial model call. Start with core tools; select or request bigger manifests only when needed.

## Policy constraints

- Do not break Berker's userspace. No runtime default change until measured, documented, reversible, and tested.
- `/home/hermes/dotfiles` remains the source of truth. No direct durable edits to `~/.hermes/config.yaml`.
- Telegram keeps full remote operations by default unless Berker explicitly changes that preference.
- `web` remains always-on for default CLI.
- Survival tools should remain available in normal CLI: terminal, file, skills, memory, session_search, todo, clarify. Add `code_execution` because it reduces multi-call overhead and lets us measure/transform data cheaply.
- Every split must have an escape hatch: `full-ops` or an equivalent profile/router target.

## Active tool schema inventory

| Toolset | Schema tokens | Recommended default policy | Tools | Notes |
|---|---:|---|---|---|
| `cronjob` | 1,640 | manifest-gated, not universal core | `cronjob` | High-cost single schema. Needed for schedule management, not ordinary chat. |
| `delegation` | 1,550 | core-agentic or coding/setup only | `delegate_task` | High value but high schema cost. Keep in agentic/coding/setup profiles; consider removing from cheapest core. |
| `terminal` | 1,293 | core | `process`, `terminal` | Consider upstream split between foreground terminal and process control if needed. |
| `browser` | 1,224 | manifest-gated, not universal core | `browser_back`, `browser_click`, `browser_console`, `browser_get_images`, `browser_navigate`, `browser_press`, `browser_scroll`, `browser_snapshot`, `browser_type`, `browser_vision` | Useful but often unnecessary if `web` can answer. Gate behind research/coding/media/full-ops. |
| `skills` | 1,107 | core | `skill_manage`, `skill_view`, `skills_list` | Consider upstream split into read-only `skills_read` and write-capable `skills_write`; `skill_manage` is 856 tokens. |
| `file` | 1,085 | core | `patch`, `read_file`, `search_files`, `write_file` | Consider upstream split read/search vs write/patch for read-only research profiles. |
| `session_search` | 1,000 | core | `session_search` | Costly but important for cross-session continuity; keep core unless a no-memory cheap mode is created. |
| `code_execution` | 660 | core | `execute_code` |  |
| `memory` | 463 | core | `memory` |  |
| `messaging` | 347 | manifest-gated, not universal core | `send_message` |  |
| `web` | 331 | core | `web_extract`, `web_search` |  |
| `todo` | 288 | core | `todo` |  |
| `clarify` | 279 | core | `clarify` |  |
| `tts` | 202 | domain manifest only | `text_to_speech` |  |
| `vision` | 188 | domain manifest only | `vision_analyze` |  |
| `video` | 170 | domain manifest only | `video_analyze` |  |
| `moa` | 126 | domain manifest only | `mixture_of_agents` |  |

### Immediate schema-savings thought experiment

- Current active schema budget: **11,953 tokens**.
- `core-agentic` schema budget (`web, terminal, file, code_execution, skills, clarify, todo, memory, session_search, delegation`): **8,056 tokens**, saving **3,897 schema tokens** (32.6% of schema budget).
- `core` without delegation: **6,506 tokens**, saving **5,447 schema tokens** (45.6% of schema budget).
- These are schema-only estimates. The full request savings also depends on prompt text, memory, context files, and provider prompt caching.

## Proposed hierarchy

```text
Hermes capability surface
├── Core kernel
│   ├── core: web, terminal, file, code_execution, skills, clarify, todo, memory, session_search
│   └── core-agentic: core + delegation
├── Operational overlays
│   ├── full-ops: everything currently available, used as escape hatch and Telegram default
│   ├── setup-worker: NixOS/dotfiles/Hermes config/services/profile/router work
│   ├── coding: repo/code/test/GitHub/subagent work
│   ├── cron-minimal: scheduled jobs that do not administer cron itself
│   └── cron-admin: create/update/remove/list jobs and deliver messages
├── Research and knowledge overlays
│   ├── research: web/browser/file/session recall/vision
│   ├── academic: research + arxiv/papers/ocr docs skills
│   └── productivity: docs/sheets/notion/linear/maps/email workflows
├── Creation overlays
│   ├── creative-light: diagrams/mockups/images
│   ├── media-creation: image/video/audio/tts/youtube/gifs/music
│   └── design: design systems, HTML artifacts, diagrams
├── Environment overlays
│   ├── smart-home: Home Assistant / Hue
│   ├── gaming: Minecraft, Pokemon, game server ops
│   └── apple/local-desktop: macOS/iMessage/FindMy/Notes/Reminders
└── Specialized ML/security overlays
    ├── mlops: HF, fine-tuning, evals, serving, inference
    └── red-team: godmode/jailbreak/eval-style isolated usage
```

## Proposed manifests

Token counts below are estimates from currently active schema-bearing toolsets only. Some configured toolsets currently add no schema in this environment because their requirements/env/modules are unavailable or not selected; they still belong in domain manifests for routing/documentation.

| Manifest | Estimated active schema tokens | Approx schema savings vs current | Intended use | Toolsets |
|---|---:|---:|---|---|
| `core` | 6,506 | 5,447 | Lowest normal CLI surface. Use for ordinary Q&A, reading, small edits, local diagnosis. | `web`, `terminal`, `file`, `code_execution`, `skills`, `clarify`, `todo`, `memory`, `session_search` |
| `core-agentic` | 8,056 | 3,897 | Default candidate if we want delegation available in normal work. | `web`, `terminal`, `file`, `code_execution`, `skills`, `clarify`, `todo`, `memory`, `session_search`, `delegation` |
| `full-ops` | 11,953 | 0 | Escape hatch and Telegram default. No functionality removed. | `web`, `browser`, `terminal`, `file`, `code_execution`, `skills`, `clarify`, `todo`, `memory`, `session_search`, `delegation`, `cronjob`, `messaging`, `vision`, `image_gen`, `video`, `video_gen`, `x_search`, `moa`, `tts`, `homeassistant`, `spotify`, `yuanbao`, `computer_use`, `file_io`, `shell`, `execute_command`, `patch` |
| `coding` | 9,001 | 2,952 | Repo work, tests, debugging, PR prep, implementation tasks. | `web`, `terminal`, `file`, `code_execution`, `skills`, `todo`, `memory`, `session_search`, `delegation`, `browser` |
| `setup-worker` | 10,988 | 965 | Hermes/NixOS/dotfiles/services/profile/router work. | `web`, `terminal`, `file`, `code_execution`, `skills`, `todo`, `memory`, `session_search`, `delegation`, `cronjob`, `messaging`, `browser` |
| `research` | 5,965 | 5,988 | Web-heavy research, dynamic pages, citations, screenshots/images. | `web`, `browser`, `file`, `skills`, `memory`, `session_search`, `todo`, `clarify`, `vision` |
| `media-creation` | 6,337 | 5,616 | Image/video/audio generation and analysis workflows. | `web`, `browser`, `file`, `skills`, `memory`, `session_search`, `todo`, `clarify`, `vision`, `image_gen`, `video`, `video_gen`, `tts` |
| `smart-home` | 3,815 | 8,138 | Home Assistant/Hue control plus messaging confirmations. | `web`, `skills`, `memory`, `session_search`, `todo`, `clarify`, `homeassistant`, `messaging` |
| `gaming` | 9,280 | 2,673 | Game server setup, modpacks, emulator/game automation tasks. | `web`, `browser`, `terminal`, `file`, `code_execution`, `skills`, `memory`, `session_search`, `todo`, `clarify`, `delegation` |
| `communications` | 5,102 | 6,851 | Send/read/draft cross-platform messages and voice/audio replies. | `web`, `file`, `skills`, `memory`, `session_search`, `todo`, `clarify`, `messaging`, `tts` |
| `cron-minimal` | 6,227 | 5,726 | Cheap no-admin scheduled runs; jobs should opt into more if needed. | `web`, `terminal`, `file`, `code_execution`, `skills`, `memory`, `session_search`, `todo` |
| `cron-admin` | 8,214 | 3,739 | Cron management and delivery workflows. | `web`, `terminal`, `file`, `code_execution`, `skills`, `memory`, `session_search`, `todo`, `cronjob`, `messaging` |
| `creative-light` | 4,741 | 7,212 | Small diagrams/mockups/image creation without video/audio bulk. | `web`, `file`, `skills`, `memory`, `session_search`, `todo`, `clarify`, `vision`, `image_gen` |
| `mlops` | 9,280 | 2,673 | Model download, serving, training, eval, HF work. | `web`, `browser`, `terminal`, `file`, `code_execution`, `skills`, `memory`, `session_search`, `todo`, `clarify`, `delegation` |

## Skill hierarchy inventory

Installed skills show the natural split boundaries. Counts include local duplicate copies where present; deduplication is a separate cleanup task and should be handled carefully because profile-local skills may intentionally shadow shared skills.

| Skill category | Count | Representative skills | Proposed manifest(s) |
|---|---:|---|---|
| `apple` | 5 | `apple-notes`, `apple-reminders`, `findmy`, `imessage`, `macos-computer-use` | apple/local-desktop, communications |
| `autonomous-ai-agents` | 11 | `claude-code`, `codex`, `hermes-agent`, `hermes-dashboard-operations`, `hermes-memory-configuration-audits`, `hermes-profile-skill-management`, `hermes-setup-improvement-implementer`, `hermes-setup-improvement-research`, `kanban-codex-lane`, `opencode`, `profile-router` | setup-worker, coding, full-ops |
| `creative` | 25 | `architecture-diagram`, `ascii-art`, `ascii-video`, `baoyu-article-illustrator`, `baoyu-comic`, `baoyu-infographic`, `claude-design`, `comfyui`, `comfyui`, `design-md`, `eikon`, `eikon-create` ... | creative-light, media-creation, design |
| `data-science` | 1 | `jupyter-live-kernel` | mlops, research |
| `devops` | 9 | `kanban-orchestrator`, `kanban-orchestrator`, `kanban-task-creation`, `kanban-task-router`, `kanban-worker`, `kanban-worker`, `nixos-hermes-home-node`, `tailscale-private-networking`, `webhook-subscriptions` | setup-worker, full-ops |
| `email` | 6 | `declarative-email-on-nixos`, `email-sending-workflows`, `himalaya`, `himalaya`, `himalaya-calendar-invites`, `otto-email-signature` | communications, productivity |
| `gaming` | 2 | `minecraft-modpack-server`, `pokemon-player` | gaming |
| `github` | 7 | `codebase-inspection`, `github-auth`, `github-code-review`, `github-issues`, `github-pr-workflow`, `github-repo-management`, `sync-my-githubs` | coding |
| `mcp` | 1 | `native-mcp` | setup-worker, full-ops |
| `media` | 6 | `gif-search`, `heartmula`, `songsee`, `spotify`, `youtube-content`, `youtube-metadata-inventories` | media-creation, research |
| `mlops` | 1 | `huggingface-hub` | mlops |
| `mlops/evaluation` | 2 | `evaluating-llms-harness`, `weights-and-biases` | mlops |
| `mlops/inference` | 4 | `llama-cpp`, `obliteratus`, `outlines`, `serving-llms-vllm` | mlops |
| `mlops/models` | 2 | `audiocraft-audio-generation`, `segment-anything-model` | mlops, media-creation |
| `mlops/research` | 1 | `dspy` | mlops, research |
| `mlops/training` | 3 | `axolotl`, `fine-tuning-with-trl`, `unsloth` | mlops |
| `note-taking` | 1 | `obsidian` | productivity, research |
| `productivity` | 13 | `airtable`, `google-workspace`, `google-workspace`, `linear`, `maps`, `maps`, `nano-pdf`, `notion`, `notion`, `ocr-and-documents`, `ocr-and-documents`, `powerpoint` ... | productivity, communications |
| `red-teaming` | 1 | `godmode` | red-team |
| `research` | 7 | `arxiv`, `arxiv`, `blogwatcher`, `llm-wiki`, `polymarket`, `polymarket`, `research-paper-writing` | research, academic |
| `root` | 2 | `dogfood`, `yuanbao` | full-ops / inspect category |
| `smart-home` | 1 | `openhue` | smart-home |
| `social-media` | 1 | `xurl` | communications, research |
| `software-development` | 12 | `debugging-hermes-tui-commands`, `hermes-agent-skill-authoring`, `hermes-tui-debugging`, `node-inspect-debugger`, `plan`, `python-debugpy`, `requesting-code-review`, `spike`, `subagent-driven-development`, `systematic-debugging`, `test-driven-development`, `writing-plans` | coding, setup-worker |
| `system` | 2 | `locating-files`, `otto-wiki` | core, setup-worker |

## Full skill list by category

### apple (5)

- `apple-notes`: Manage Apple Notes via memo CLI: create, search, edit.
- `apple-reminders`: Apple Reminders via remindctl: add, list, complete.
- `findmy`: Track Apple devices/AirTags via FindMy.app on macOS.
- `imessage`: Send and receive iMessages/SMS via the imsg CLI on macOS.
- `macos-computer-use`: \|

### autonomous-ai-agents (11)

- `claude-code`: Delegate coding to Claude Code CLI (features, PRs).
- `codex`: Delegate coding to OpenAI Codex CLI (features, PRs).
- `hermes-agent`: Configure, extend, or contribute to Hermes Agent.
- `hermes-dashboard-operations`: Operate and troubleshoot Hermes Agent dashboard/web UI services, including WebSocket chat/event feed issues.
- `hermes-memory-configuration-audits`: Audit and fix Hermes Agent memory/profile/compression configuration on Otto/hermesbox, preserving declarative NixOS source of truth.
- `hermes-profile-skill-management`: Manage skill availability for isolated Hermes profiles and kanban workers, especially shared skill directories and missing preloaded skills.
- `hermes-setup-improvement-implementer`: Use when Berker asks to implement a numbered item from the Hermes setup improvement backlog autonomously and verify it.
- `hermes-setup-improvement-research`: Use when researching, triaging, and maintaining a numbered checklist of possible improvements to Berker/Otto's Hermes setup.
- `kanban-codex-lane`: Use when a Hermes Kanban worker wants to run Codex CLI as an isolated implementation lane while Hermes keeps ownership of task lifecycle, reconciliation, testing, and handoff.
- `opencode`: Delegate coding to OpenCode CLI (features, PR review).
- `profile-router`: Route user requests from the lightweight default profile to specialist Hermes profiles using dynamic PROFILE.md metadata.

### creative (25)

- `architecture-diagram`: Dark-themed SVG architecture/cloud/infra diagrams as HTML.
- `ascii-art`: ASCII art: pyfiglet, cowsay, boxes, image-to-ascii.
- `ascii-video`: ASCII video: convert video/audio to colored ASCII MP4/GIF.
- `baoyu-article-illustrator`: Article illustrations: type × style × palette consistency.
- `baoyu-comic`: Knowledge comics (知识漫画): educational, biography, tutorial.
- `baoyu-infographic`: Infographics: 21 layouts x 21 styles (信息图, 可视化).
- `claude-design`: Design one-off HTML artifacts (landing, deck, prototype).
- `comfyui`: Generate images, video, and audio with ComfyUI — install, launch, manage nodes/models, run workflows with parameter injection. Uses the official comfy-cli for lifecycle and direct REST/WebSocket API for execution.
- `comfyui`: Generate images, video, and audio with ComfyUI — install, launch, manage nodes/models, run workflows with parameter injection. Uses the official comfy-cli for lifecycle and direct REST/WebSocket API for execution.
- `design-md`: Author/validate/export Google's DESIGN.md token spec files.
- `eikon`: Guide the user through making or editing a herm sidebar avatar (eikon) using herm's built-in Eikon Studio tab. The agent's role is advisory (what makes a good source, which knob to reach for); source generation is /eikon-create and all rasterize/bake happens in-app.
- `eikon-create`: Interactively generate source images (and optionally short videos) for a herm eikon avatar, iterate on them with the user, and land them under ~/.hermes/eikons/<name>/source/ so the Eikon Studio tab can tune and bake them. This is the agent-driven counterpart to Studio's one-shot Generate dialog.
- `excalidraw`: Hand-drawn Excalidraw JSON diagrams (arch, flow, seq).
- `humanizer`: Humanize text: strip AI-isms and add real voice.
- `hyperframes`: Create HTML-based video compositions, animated title cards, social overlays, captioned talking-head videos, audio-reactive visuals, and shader transitions using HyperFrames. HTML is the source of truth for video. Use when the user wants a rendered MP4/WebM from an HTML composition, wants to animate text/logos/charts over media, needs captions synced to audio, wants TTS narration, or wants to convert a website into a video.
- `hyperframes-design-systems`: Create and research HyperFrames/Hermes design.md or DESIGN.md visual-identity files for generated videos and UI demos.
- `ideation`: Generate project ideas via creative constraints.
- `manim-video`: Manim CE animations: 3Blue1Brown math/algo videos.
- `p5js`: p5.js sketches: gen art, shaders, interactive, 3D.
- `pixel-art`: Pixel art w/ era palettes (NES, Game Boy, PICO-8).
- `popular-web-designs`: 54 real design systems (Stripe, Linear, Vercel) as HTML/CSS.
- `pretext`: Use when building creative browser demos with @chenglou/pretext — DOM-free text layout for ASCII art, typographic flow around obstacles, text-as-geometry games, kinetic typography, and text-powered generative art. Produces single-file HTML demos by default.
- `sketch`: Throwaway HTML mockups: 2-3 design variants to compare.
- `songwriting-and-ai-music`: Songwriting craft and Suno AI music prompts.
- `touchdesigner-mcp`: Control a running TouchDesigner instance via twozero MCP — create operators, set parameters, wire connections, execute Python, build real-time visuals. 36 native tools.

### data-science (1)

- `jupyter-live-kernel`: Iterative Python via live Jupyter kernel (hamelnb).

### devops (9)

- `kanban-orchestrator`: Decomposition playbook + specialist-roster conventions + anti-temptation rules for an orchestrator profile routing work through Kanban. The "don't do the work yourself" rule and the basic lifecycle are auto-injected into every kanban worker's system prompt; this skill is the deeper playbook when you're specifically playing the orchestrator role.
- `kanban-orchestrator`: Decomposition playbook + specialist-roster conventions + anti-temptation rules for an orchestrator profile routing work through Kanban. The "don't do the work yourself" rule and the basic lifecycle are auto-injected into every kanban worker's system prompt; this skill is the deeper playbook when you're specifically playing the orchestrator role.
- `kanban-task-creation`: Use when Berker asks to post, put, make, create, or dispatch a Kanban card from a specific spec. Defaults parked/non-running unless explicit start/run/dispatch intent is present.
- `kanban-task-router`: Route kanban tasks to the right profile based on complexity, domain, and tool requirements. Use this whenever creating a kanban card to set the correct assignee and skills.
- `kanban-worker`: Pitfalls, examples, and edge cases for Hermes Kanban workers. The lifecycle itself is auto-injected into every worker's system prompt as KANBAN_GUIDANCE (from agent/prompt_builder.py); this skill is what you load when you want deeper detail on specific scenarios.
- `kanban-worker`: Pitfalls, examples, and edge cases for Hermes Kanban workers. The lifecycle itself is auto-injected into every worker's system prompt as KANBAN_GUIDANCE (from agent/prompt_builder.py); this skill is what you load when you want deeper detail on specific scenarios.
- `nixos-hermes-home-node`: Plan and implement reproducible, hardened NixOS home-node deployments for Hermes Agent.
- `tailscale-private-networking`: Use when setting up Tailscale/tailnet private networking on Linux or NixOS: auth-key enrollment, MagicDNS, Tailscale SSH, private dashboard/service access, Tailscale Serve, subnet routing, and exit-node/VPN behavior.
- `webhook-subscriptions`: Webhook subscriptions: event-driven agent runs.

### email (6)

- `declarative-email-on-nixos`: Configure terminal email clients declaratively on NixOS with runtime-loaded secrets.
- `email-sending-workflows`: Class-level patterns for reliable terminal email sending workflows and verification.
- `himalaya`: Himalaya CLI: IMAP/SMTP email from terminal.
- `himalaya`: Himalaya CLI: IMAP/SMTP email from terminal.
- `himalaya-calendar-invites`: Create and send .ics meeting invites via Himalaya without duplicate sends.
- `otto-email-signature`: Default rich HTML signature block for Otto outgoing emails via Himalaya.

### gaming (2)

- `minecraft-modpack-server`: Host modded Minecraft servers (CurseForge, Modrinth).
- `pokemon-player`: Play Pokemon via headless emulator + RAM reads.

### github (7)

- `codebase-inspection`: Inspect codebases w/ pygount: LOC, languages, ratios.
- `github-auth`: GitHub auth setup: HTTPS tokens, SSH keys, gh CLI login.
- `github-code-review`: Review PRs: diffs, inline comments via gh or REST.
- `github-issues`: Create, triage, label, assign GitHub issues via gh or REST.
- `github-pr-workflow`: GitHub PR lifecycle: branch, commit, open, CI, merge.
- `github-repo-management`: Clone/create/fork repos; manage remotes, releases.
- `sync-my-githubs`: Use when Berker asks to sync Otto's GitHub-backed state/repos, especially Hermes brain files and dotfiles. Runs the known local sync jobs or equivalent git status/add/commit/push checks, without exposing secrets.

### mcp (1)

- `native-mcp`: MCP client: connect servers, register tools (stdio/HTTP).

### media (6)

- `gif-search`: Search/download GIFs from Tenor via curl + jq.
- `heartmula`: HeartMuLa: Suno-like song generation from lyrics + tags.
- `songsee`: Audio spectrograms/features (mel, chroma, MFCC) via CLI.
- `spotify`: Spotify: play, search, queue, manage playlists and devices.
- `youtube-content`: YouTube transcripts to summaries, threads, blogs.
- `youtube-metadata-inventories`: Create spreadsheets/lists of YouTube videos from channel/search/playlist URLs with title, link, date, and chronological ordering.

### mlops (1)

- `huggingface-hub`: HuggingFace hf CLI: search/download/upload models, datasets.

### mlops/evaluation (2)

- `evaluating-llms-harness`: lm-eval-harness: benchmark LLMs (MMLU, GSM8K, etc.).
- `weights-and-biases`: W&B: log ML experiments, sweeps, model registry, dashboards.

### mlops/inference (4)

- `llama-cpp`: llama.cpp local GGUF inference + HF Hub model discovery.
- `obliteratus`: OBLITERATUS: abliterate LLM refusals (diff-in-means).
- `outlines`: Outlines: structured JSON/regex/Pydantic LLM generation.
- `serving-llms-vllm`: vLLM: high-throughput LLM serving, OpenAI API, quantization.

### mlops/models (2)

- `audiocraft-audio-generation`: AudioCraft: MusicGen text-to-music, AudioGen text-to-sound.
- `segment-anything-model`: SAM: zero-shot image segmentation via points, boxes, masks.

### mlops/research (1)

- `dspy`: DSPy: declarative LM programs, auto-optimize prompts, RAG.

### mlops/training (3)

- `axolotl`: Axolotl: YAML LLM fine-tuning (LoRA, DPO, GRPO).
- `fine-tuning-with-trl`: TRL: SFT, DPO, PPO, GRPO, reward modeling for LLM RLHF.
- `unsloth`: Unsloth: 2-5x faster LoRA/QLoRA fine-tuning, less VRAM.

### note-taking (1)

- `obsidian`: Read, search, create, and edit notes in the Obsidian vault.

### productivity (13)

- `airtable`: Airtable REST API via curl. Records CRUD, filters, upserts.
- `google-workspace`: Gmail, Calendar, Drive, Docs, Sheets via gws CLI or Python.
- `google-workspace`: Gmail, Calendar, Drive, Docs, Sheets via gws CLI or Python.
- `linear`: Linear: manage issues, projects, teams via GraphQL + curl.
- `maps`: Geocode, POIs, routes, timezones via OpenStreetMap/OSRM.
- `maps`: Geocode, POIs, routes, timezones via OpenStreetMap/OSRM.
- `nano-pdf`: Edit PDF text/typos/titles via nano-pdf CLI (NL prompts).
- `notion`: Notion API + ntn CLI: pages, databases, markdown, Workers.
- `notion`: Notion API via curl: pages, databases, blocks, search.
- `ocr-and-documents`: Extract text from PDFs/scans (pymupdf, marker-pdf).
- `ocr-and-documents`: Extract text from PDFs/scans (pymupdf, marker-pdf).
- `powerpoint`: Create, read, edit .pptx decks, slides, notes, templates.
- `teams-meeting-pipeline`: Operate the Teams meeting summary pipeline via Hermes CLI — summarize meetings, inspect pipeline status, replay jobs, manage Microsoft Graph subscriptions.

### red-teaming (1)

- `godmode`: Jailbreak LLMs: Parseltongue, GODMODE, ULTRAPLINIAN.

### research (7)

- `arxiv`: Search arXiv papers by keyword, author, category, or ID.
- `arxiv`: Search arXiv papers by keyword, author, category, or ID.
- `blogwatcher`: Monitor blogs and RSS/Atom feeds via blogwatcher-cli tool.
- `llm-wiki`: Karpathy's LLM Wiki: build/query interlinked markdown KB.
- `polymarket`: Query Polymarket: markets, prices, orderbooks, history.
- `polymarket`: Query Polymarket: markets, prices, orderbooks, history.
- `research-paper-writing`: Write ML papers for NeurIPS/ICML/ICLR: design→submit.

### root (2)

- `dogfood`: Exploratory QA of web apps: find bugs, evidence, reports.
- `yuanbao`: Yuanbao (元宝) groups: @mention users, query info/members.

### smart-home (1)

- `openhue`: Control Philips Hue lights, scenes, rooms via OpenHue CLI.

### social-media (1)

- `xurl`: X/Twitter via xurl CLI: post, search, DM, media, v2 API.

### software-development (12)

- `debugging-hermes-tui-commands`: Debug Hermes TUI slash commands: Python, gateway, Ink UI.
- `hermes-agent-skill-authoring`: Author in-repo SKILL.md: frontmatter, validator, structure.
- `hermes-tui-debugging`: Debug Hermes TUI input, viewport, modal prompts, and slash-command UX.
- `node-inspect-debugger`: Debug Node.js via --inspect + Chrome DevTools Protocol CLI.
- `plan`: Plan mode: write markdown plan to .hermes/plans/, no exec.
- `python-debugpy`: Debug Python: pdb REPL + debugpy remote (DAP).
- `requesting-code-review`: Pre-commit review: security scan, quality gates, auto-fix.
- `spike`: Throwaway experiments to validate an idea before build.
- `subagent-driven-development`: Execute plans via delegate_task subagents (2-stage review).
- `systematic-debugging`: 4-phase root cause debugging: understand bugs before fixing.
- `test-driven-development`: TDD: enforce RED-GREEN-REFACTOR, tests before code.
- `writing-plans`: Write implementation plans: bite-sized tasks, paths, code.

### system (2)

- `locating-files`: Workflows for locating files and directories when the path is uncertain.
- `otto-wiki`: Load Otto's structured knowledge wiki: retrieve wiki pages by topic, list categories, search content.

## Routing rules

Routing should be explicit and conservative. If confidence is low, route to `full-ops` or ask once. Do not strand a task in a profile without the tools needed to recover.

| Trigger language / task shape | Preferred manifest | Escalation |
|---|---|---|
| Generic explanation, small local check, normal chat, simple file read/edit | `core` or `core-agentic` | `full-ops` if task mentions scheduling, messaging, media, smart home, browser automation |
| Codebase implementation, tests, debugging, PR/GitHub work | `coding` | `setup-worker` for Hermes/NixOS; `full-ops` for messaging/release automation |
| Hermes Agent config, models, providers, profiles, skills, gateway, NixOS services | `setup-worker` | `full-ops` only if cross-platform operations are needed |
| Web research, dynamic page interaction, scraping/citations | `research` | `media-creation` if image/video/audio generation appears |
| Generate/edit image/video/audio/song/diagram/mockup | `media-creation` or `creative-light` | `full-ops` if sending/publishing elsewhere |
| Lights, Home Assistant, Hue, sensors, rooms | `smart-home` | `full-ops` for notifications or unrelated ops |
| Minecraft/modpacks/Pokemon/emulator/game server | `gaming` | `setup-worker` for host/service hardening |
| Send message/email/social post/calendar invite | `communications` or `productivity` | `full-ops` for arbitrary remote command/control |
| Scheduled jobs | `cron-minimal` for execution, `cron-admin` for management | `setup-worker` for root/systemd timers |
| Model serving/fine-tuning/evals/Hugging Face | `mlops` | `coding` for repo implementation |

## Implementation approach

### Phase 0: keep current default unchanged

Do not change runtime defaults while designing. Continue using `docs/hermes-prompt-budget-baseline.md` and extend `hermes-prompt-budget` to support simulated manifests. This gives before/after numbers without affecting any live session.

### Phase 1: add declarative manifest data

Add a Nix-managed manifest table under `/home/hermes/dotfiles`, likely in `hosts/hermesbox/hermes-profiles.nix` or a new `hosts/hermesbox/hermes-capability-manifests.nix`. Each manifest should include:

```nix
{
  name = "coding";
  description = "Repo/code/test/GitHub work";
  toolsets = [ "web" "terminal" "file" "code_execution" "skills" "todo" "memory" "session_search" "delegation" "browser" ];
  skills = [ "systematic-debugging" "test-driven-development" "github-pr-workflow" ];
  fallback = "full-ops";
  tags = [ "code" "repo" "tests" "github" ];
}
```

This should generate profile metadata and/or router metadata, not necessarily immediately change `services.hermes-agent.settings.toolsets`.

### Phase 2: enhance `hermes-prompt-budget`

Add options:

```bash
hermes-prompt-budget --manifest core
hermes-prompt-budget --manifest coding
hermes-prompt-budget --all-manifests
hermes-prompt-budget --compare current,core,coding,full-ops
```

Output should include total prompt tokens, schema tokens, estimated savings/request, and projected savings at 1k/10k/100k requests. No runtime behavior change required.

### Phase 3: create profiles without making them default

Generate or define named Hermes profiles for each manifest, sharing common skills through `skills.external_dirs`. Verify each profile starts and can answer a smoke-test prompt. Keep default CLI and Telegram unchanged.

Smoke tests should include:

- `hermes --profile core chat -q "Say ready"`
- `hermes --profile coding chat -q "List available coding survival tools"`
- `hermes --profile setup-worker chat -q "Where is the dotfiles source of truth?"`
- `hermes --profile full-ops chat -q "List enabled toolsets"`

### Phase 4: route obvious tasks

Update `hermes-profile-router` metadata/rules to choose manifests. Start with advisory mode: print the recommended profile and command, but do not auto-exec unless explicitly requested. Then enable execution for low-risk cases.

### Phase 5: change CLI default only after burn-in

After measurement and burn-in, consider setting default CLI to `core-agentic` or `core`, while keeping Telegram as `full-ops`. Include a visible escape hatch in docs and shell aliases.

## Upstream toolset split proposals

These require Hermes Agent code changes, not just dotfiles config, but they are the cleanest way to save tokens without losing capability.

| Current toolset | Current issue | Proposed split | Why |
|---|---|---|---|
| `skills` | `skill_manage` is 856 tokens but most turns only need reading. | `skills_read`: `skills_list`, `skill_view`; `skills_write`: `skill_manage` | Keep skill lookup cheap; load mutation only when creating/patching skills. |
| `file` | Read/search and write/patch have different safety/cost profiles. | `file_read`: `read_file`, `search_files`; `file_write`: `write_file`, `patch` | Research/inspection profiles can avoid write tools and their schema. |
| `terminal` | `terminal` is core, `process` is only needed for background jobs/servers. | `terminal_exec`; `process_control` | Most shell tasks do not need process session management. |
| `cronjob` | One large schema covers create/list/update/pause/remove/run and many delivery features. | `cron_read`, `cron_run`, `cron_admin` | Cron execution/smoke checks are cheaper than full scheduler administration. |
| `delegation` | Big schema because it encodes many routing/ACP/subagent rules. | `delegate_basic`, `delegate_advanced` | Coding/setup can keep advanced; core could use basic or none. |
| `browser` | All browser actions load together. | `browser_nav`, `browser_interact`, `browser_debug`, `browser_vision` | Many tasks need only navigate/snapshot; console/vision/image inventory can be gated. |
| `messaging` | Sending/listing targets plus media delivery instructions are bundled. | `message_send_home`, `message_admin` | Simple “send to home channel” can be cheaper than full cross-platform target management. |

## Failure modes and protections

- **False routing to too-small profile**: provide `full-ops` fallback and let the agent say “restart under full-ops” when a needed tool is missing.
- **Prompt-cache churn**: avoid changing tools mid-conversation unless Hermes Agent has explicit support and tests for it. Prefer per-session/profile selection first.
- **Skill shadowing across profiles**: named profile homes can shadow shared skills. Use `skills.external_dirs` declaratively and audit duplicates before profile rollout.
- **Telegram degradation**: do not slim Telegram until explicitly approved. It remains full remote ops.
- **Hidden functionality loss**: every proposed default change must have a before/after tool inventory and at least one smoke test per manifest.
- **Nix drift**: all durable changes go through `/home/hermes/dotfiles`; no permanent `hermes config set` changes.

## Acceptance criteria before any runtime default change

- `nix flake check /home/hermes/dotfiles --no-build --show-trace` passes.
- `nix build /home/hermes/dotfiles#nixosConfigurations.hermesbox.config.system.build.toplevel --no-link` passes.
- `hermes-prompt-budget --all-manifests` report is committed or saved under `docs/`.
- Default CLI, Telegram, cron, and router behavior are documented.
- A rescue path exists: use `full-ops` profile or `git revert` + rebuild.
- Berker approves the specific default change after seeing measured savings.

## Recommended next action

Do not slim defaults yet. Next, extend `hermes-prompt-budget.py` to read a manifest table and produce a comparison matrix for `current`, `core`, `core-agentic`, `coding`, `setup-worker`, `research`, `media-creation`, `smart-home`, `gaming`, `cron-minimal`, `cron-admin`, and `full-ops`. Once numbers are generated, choose one low-risk profile to create declaratively and smoke-test without making it default.
