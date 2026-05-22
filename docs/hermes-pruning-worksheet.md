# Hermes Deduped Skill and Tool Pruning Worksheet

This is the practical pruning worksheet Berker asked for: deduped buckets first, no architecture essay. Use it to decide which domains should be core, profile-gated, or deleted/archived.

Status: documentation only. No runtime behavior changed.

## How to mark this up

Suggested decision tags:

- `[keep-core]`: always available in normal Otto sessions.
- `[profile]`: keep, but only load under this domain/profile.
- `[full-ops]`: keep only in full-ops / escape-hatch sessions.
- `[archive]`: move out of active skill/tool manifest, but keep in repo/history.
- `[delete]`: remove after confirming no profile depends on it.
- `[merge]`: consolidate with another skill/toolset.

## Bucket index

| Bucket | Skills | Tools | Notes |
|---|---:|---:|---|
| `core` | 2 | 16 | Always-needed operating kernel: local execution, files, memory, skills, web, todo, clarification. |
| `coding` | 19 | 1 | Code implementation/review/debugging, GitHub workflows, subagents. |
| `setup-admin` | 12 | 1 | Hermes/NixOS/dotfiles/profile/router/cron/admin operations. |
| `research` | 6 | 10 | Web/browser research, papers, knowledge bases, note lookup. |
| `productivity` | 14 | 0 | Email, docs, calendars, PDFs, notes, spreadsheets, maps, task systems. |
| `communications` | 0 | 1 | Sending messages/email/social-ish delivery workflows. |
| `media` | 6 | 3 | Audio/video/image/youtube/music/media analysis and generation. |
| `creative-design` | 24 | 0 | Diagrams, mockups, design systems, web artifacts, infographics. |
| `smart-home` | 1 | 0 | Home Assistant, Hue, sensors, rooms, automation. |
| `gaming` | 2 | 0 | Game servers, modpacks, emulator/game play automation. |
| `apple` | 5 | 0 | Apple/macOS/iMessage/FindMy/Notes/Reminders/desktop control. |
| `mlops` | 14 | 0 | LLM/ML training, inference, evals, HF, model serving. |
| `devops-kanban` | 7 | 0 | Kanban orchestration, webhooks, Tailscale, home-node ops. |
| `social` | 2 | 0 | X/Twitter, Yuanbao, social platform operations. |
| `red-team` | 1 | 1 | Jailbreak/red-team/eval-heavy tools and skills. |
| `misc-review` | 1 | 0 | Uncategorized or needs manual classification/pruning. |

Total deduped skills: **116**. Total deduped active tools: **33**.

## Skills by pruning bucket

### core

Always-needed operating kernel: local execution, files, memory, skills, web, todo, clarification.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `locating-files` | `system` | Workflows for locating files and directories when the path is uncertain. |
| `[ ]` | `otto-wiki` | `system` | Load Otto's structured knowledge wiki: retrieve wiki pages by topic, list categories, search content. |

### coding

Code implementation/review/debugging, GitHub workflows, subagents.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `codebase-inspection` | `github` | Inspect codebases w/ pygount: LOC, languages, ratios. |
| `[ ]` | `debugging-hermes-tui-commands` | `software-development` | Debug Hermes TUI slash commands: Python, gateway, Ink UI. |
| `[ ]` | `github-auth` | `github` | GitHub auth setup: HTTPS tokens, SSH keys, gh CLI login. |
| `[ ]` | `github-code-review` | `github` | Review PRs: diffs, inline comments via gh or REST. |
| `[ ]` | `github-issues` | `github` | Create, triage, label, assign GitHub issues via gh or REST. |
| `[ ]` | `github-pr-workflow` | `github` | GitHub PR lifecycle: branch, commit, open, CI, merge. |
| `[ ]` | `github-repo-management` | `github` | Clone/create/fork repos; manage remotes, releases. |
| `[ ]` | `hermes-agent-skill-authoring` | `software-development` | Author in-repo SKILL.md: frontmatter, validator, structure. |
| `[ ]` | `hermes-tui-debugging` | `software-development` | Debug Hermes TUI input, viewport, modal prompts, and slash-command UX. |
| `[ ]` | `node-inspect-debugger` | `software-development` | Debug Node.js via --inspect + Chrome DevTools Protocol CLI. |
| `[ ]` | `plan` | `software-development` | Plan mode: write markdown plan to .hermes/plans/, no exec. |
| `[ ]` | `python-debugpy` | `software-development` | Debug Python: pdb REPL + debugpy remote (DAP). |
| `[ ]` | `requesting-code-review` | `software-development` | Pre-commit review: security scan, quality gates, auto-fix. |
| `[ ]` | `spike` | `software-development` | Throwaway experiments to validate an idea before build. |
| `[ ]` | `subagent-driven-development` | `software-development` | Execute plans via delegate_task subagents (2-stage review). |
| `[ ]` | `sync-my-githubs` | `github` | Use when Berker asks to sync Otto's GitHub-backed state/repos, especially Hermes brain files and dotfiles. Runs the known local sync jobs or equivalent git status/add/commit/push checks, without exposing secrets. |
| `[ ]` | `systematic-debugging` | `software-development` | 4-phase root cause debugging: understand bugs before fixing. |
| `[ ]` | `test-driven-development` | `software-development` | TDD: enforce RED-GREEN-REFACTOR, tests before code. |
| `[ ]` | `writing-plans` | `software-development` | Write implementation plans: bite-sized tasks, paths, code. |

### setup-admin

Hermes/NixOS/dotfiles/profile/router/cron/admin operations.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `claude-code` | `autonomous-ai-agents` | Delegate coding to Claude Code CLI (features, PRs). |
| `[ ]` | `codex` | `autonomous-ai-agents` | Delegate coding to OpenAI Codex CLI (features, PRs). |
| `[ ]` | `hermes-agent` | `autonomous-ai-agents` | Configure, extend, or contribute to Hermes Agent. |
| `[ ]` | `hermes-dashboard-operations` | `autonomous-ai-agents` | Operate and troubleshoot Hermes Agent dashboard/web UI services, including WebSocket chat/event feed issues. |
| `[ ]` | `hermes-memory-configuration-audits` | `autonomous-ai-agents` | Audit and fix Hermes Agent memory/profile/compression configuration on Otto/hermesbox, preserving declarative NixOS source of truth. |
| `[ ]` | `hermes-profile-skill-management` | `autonomous-ai-agents` | Manage skill availability for isolated Hermes profiles and kanban workers, especially shared skill directories and missing preloaded skills. |
| `[ ]` | `hermes-setup-improvement-implementer` | `autonomous-ai-agents` | Use when Berker asks to implement a numbered item from the Hermes setup improvement backlog autonomously and verify it. |
| `[ ]` | `hermes-setup-improvement-research` | `autonomous-ai-agents` | Use when researching, triaging, and maintaining a numbered checklist of possible improvements to Berker/Otto's Hermes setup. |
| `[ ]` | `kanban-codex-lane` | `autonomous-ai-agents` | Use when a Hermes Kanban worker wants to run Codex CLI as an isolated implementation lane while Hermes keeps ownership of task lifecycle, reconciliation, testing, and handoff. |
| `[ ]` | `native-mcp` | `mcp` | MCP client: connect servers, register tools (stdio/HTTP). |
| `[ ]` | `opencode` | `autonomous-ai-agents` | Delegate coding to OpenCode CLI (features, PR review). |
| `[ ]` | `profile-router` | `autonomous-ai-agents` | Route user requests from the lightweight default profile to specialist Hermes profiles using dynamic PROFILE.md metadata. |

### research

Web/browser research, papers, knowledge bases, note lookup.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `arxiv` | `research` | Search arXiv papers by keyword, author, category, or ID. |
| `[ ]` | `blogwatcher` | `research` | Monitor blogs and RSS/Atom feeds via blogwatcher-cli tool. |
| `[ ]` | `llm-wiki` | `research` | Karpathy's LLM Wiki: build/query interlinked markdown KB. |
| `[ ]` | `obsidian` | `note-taking` | Read, search, create, and edit notes in the Obsidian vault. |
| `[ ]` | `polymarket` | `research` | Query Polymarket: markets, prices, orderbooks, history. |
| `[ ]` | `research-paper-writing` | `research` | Write ML papers for NeurIPS/ICML/ICLR: design→submit. |

### productivity

Email, docs, calendars, PDFs, notes, spreadsheets, maps, task systems.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `airtable` | `productivity` | Airtable REST API via curl. Records CRUD, filters, upserts. |
| `[ ]` | `declarative-email-on-nixos` | `email` | Configure terminal email clients declaratively on NixOS with runtime-loaded secrets. |
| `[ ]` | `email-sending-workflows` | `email` | Class-level patterns for reliable terminal email sending workflows and verification. |
| `[ ]` | `google-workspace` | `productivity` | Gmail, Calendar, Drive, Docs, Sheets via gws CLI or Python. |
| `[ ]` | `himalaya` | `email` | Himalaya CLI: IMAP/SMTP email from terminal. |
| `[ ]` | `himalaya-calendar-invites` | `email` | Create and send .ics meeting invites via Himalaya without duplicate sends. |
| `[ ]` | `linear` | `productivity` | Linear: manage issues, projects, teams via GraphQL + curl. |
| `[ ]` | `maps` | `productivity` | Geocode, POIs, routes, timezones via OpenStreetMap/OSRM. |
| `[ ]` | `nano-pdf` | `productivity` | Edit PDF text/typos/titles via nano-pdf CLI (NL prompts). |
| `[ ]` | `notion` | `productivity` | Notion API + ntn CLI: pages, databases, markdown, Workers. |
| `[ ]` | `ocr-and-documents` | `productivity` | Extract text from PDFs/scans (pymupdf, marker-pdf). |
| `[ ]` | `otto-email-signature` | `email` | Default rich HTML signature block for Otto outgoing emails via Himalaya. |
| `[ ]` | `powerpoint` | `productivity` | Create, read, edit .pptx decks, slides, notes, templates. |
| `[ ]` | `teams-meeting-pipeline` | `productivity` | Operate the Teams meeting summary pipeline via Hermes CLI — summarize meetings, inspect pipeline status, replay jobs, manage Microsoft Graph subscriptions. |

### communications

Sending messages/email/social-ish delivery workflows.

_No deduped skills currently assigned._

### media

Audio/video/image/youtube/music/media analysis and generation.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `gif-search` | `media` | Search/download GIFs from Tenor via curl + jq. |
| `[ ]` | `heartmula` | `media` | HeartMuLa: Suno-like song generation from lyrics + tags. |
| `[ ]` | `songsee` | `media` | Audio spectrograms/features (mel, chroma, MFCC) via CLI. |
| `[ ]` | `spotify` | `media` | Spotify: play, search, queue, manage playlists and devices. |
| `[ ]` | `youtube-content` | `media` | YouTube transcripts to summaries, threads, blogs. |
| `[ ]` | `youtube-metadata-inventories` | `media` | Create spreadsheets/lists of YouTube videos from channel/search/playlist URLs with title, link, date, and chronological ordering. |

### creative-design

Diagrams, mockups, design systems, web artifacts, infographics.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `architecture-diagram` | `creative` | Dark-themed SVG architecture/cloud/infra diagrams as HTML. |
| `[ ]` | `ascii-art` | `creative` | ASCII art: pyfiglet, cowsay, boxes, image-to-ascii. |
| `[ ]` | `ascii-video` | `creative` | ASCII video: convert video/audio to colored ASCII MP4/GIF. |
| `[ ]` | `baoyu-article-illustrator` | `creative` | Article illustrations: type × style × palette consistency. |
| `[ ]` | `baoyu-comic` | `creative` | Knowledge comics (知识漫画): educational, biography, tutorial. |
| `[ ]` | `baoyu-infographic` | `creative` | Infographics: 21 layouts x 21 styles (信息图, 可视化). |
| `[ ]` | `claude-design` | `creative` | Design one-off HTML artifacts (landing, deck, prototype). |
| `[ ]` | `comfyui` | `creative` | Generate images, video, and audio with ComfyUI — install, launch, manage nodes/models, run workflows with parameter injection. Uses the official comfy-cli for lifecycle and direct REST/WebSocket API for execution. |
| `[ ]` | `design-md` | `creative` | Author/validate/export Google's DESIGN.md token spec files. |
| `[ ]` | `eikon` | `creative` | Guide the user through making or editing a herm sidebar avatar (eikon) using herm's built-in Eikon Studio tab. The agent's role is advisory (what makes a good source, which knob to reach for); source generation is /eikon-create and all rasterize/bake happens in-app. |
| `[ ]` | `eikon-create` | `creative` | Interactively generate source images (and optionally short videos) for a herm eikon avatar, iterate on them with the user, and land them under ~/.hermes/eikons/<name>/source/ so the Eikon Studio tab can tune and bake them. This is the agent-driven counterpart to Studio's one-shot Generate dialog. |
| `[ ]` | `excalidraw` | `creative` | Hand-drawn Excalidraw JSON diagrams (arch, flow, seq). |
| `[ ]` | `humanizer` | `creative` | Humanize text: strip AI-isms and add real voice. |
| `[ ]` | `hyperframes` | `creative` | Create HTML-based video compositions, animated title cards, social overlays, captioned talking-head videos, audio-reactive visuals, and shader transitions using HyperFrames. HTML is the source of truth for video. Use when the user wants a rendered MP4/WebM from an HTML composition, wants to animate text/logos/charts over media, needs captions synced to audio, wants TTS narration, or wants to convert a website into a video. |
| `[ ]` | `hyperframes-design-systems` | `creative` | Create and research HyperFrames/Hermes design.md or DESIGN.md visual-identity files for generated videos and UI demos. |
| `[ ]` | `ideation` | `creative` | Generate project ideas via creative constraints. |
| `[ ]` | `manim-video` | `creative` | Manim CE animations: 3Blue1Brown math/algo videos. |
| `[ ]` | `p5js` | `creative` | p5.js sketches: gen art, shaders, interactive, 3D. |
| `[ ]` | `pixel-art` | `creative` | Pixel art w/ era palettes (NES, Game Boy, PICO-8). |
| `[ ]` | `popular-web-designs` | `creative` | 54 real design systems (Stripe, Linear, Vercel) as HTML/CSS. |
| `[ ]` | `pretext` | `creative` | Use when building creative browser demos with @chenglou/pretext — DOM-free text layout for ASCII art, typographic flow around obstacles, text-as-geometry games, kinetic typography, and text-powered generative art. Produces single-file HTML demos by default. |
| `[ ]` | `sketch` | `creative` | Throwaway HTML mockups: 2-3 design variants to compare. |
| `[ ]` | `songwriting-and-ai-music` | `creative` | Songwriting craft and Suno AI music prompts. |
| `[ ]` | `touchdesigner-mcp` | `creative` | Control a running TouchDesigner instance via twozero MCP — create operators, set parameters, wire connections, execute Python, build real-time visuals. 36 native tools. |

### smart-home

Home Assistant, Hue, sensors, rooms, automation.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `openhue` | `smart-home` | Control Philips Hue lights, scenes, rooms via OpenHue CLI. |

### gaming

Game servers, modpacks, emulator/game play automation.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `minecraft-modpack-server` | `gaming` | Host modded Minecraft servers (CurseForge, Modrinth). |
| `[ ]` | `pokemon-player` | `gaming` | Play Pokemon via headless emulator + RAM reads. |

### apple

Apple/macOS/iMessage/FindMy/Notes/Reminders/desktop control.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `apple-notes` | `apple` | Manage Apple Notes via memo CLI: create, search, edit. |
| `[ ]` | `apple-reminders` | `apple` | Apple Reminders via remindctl: add, list, complete. |
| `[ ]` | `findmy` | `apple` | Track Apple devices/AirTags via FindMy.app on macOS. |
| `[ ]` | `imessage` | `apple` | Send and receive iMessages/SMS via the imsg CLI on macOS. |
| `[ ]` | `macos-computer-use` | `apple` | \| |

### mlops

LLM/ML training, inference, evals, HF, model serving.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `audiocraft-audio-generation` | `mlops/models` | AudioCraft: MusicGen text-to-music, AudioGen text-to-sound. |
| `[ ]` | `axolotl` | `mlops/training` | Axolotl: YAML LLM fine-tuning (LoRA, DPO, GRPO). |
| `[ ]` | `dspy` | `mlops/research` | DSPy: declarative LM programs, auto-optimize prompts, RAG. |
| `[ ]` | `evaluating-llms-harness` | `mlops/evaluation` | lm-eval-harness: benchmark LLMs (MMLU, GSM8K, etc.). |
| `[ ]` | `fine-tuning-with-trl` | `mlops/training` | TRL: SFT, DPO, PPO, GRPO, reward modeling for LLM RLHF. |
| `[ ]` | `huggingface-hub` | `mlops` | HuggingFace hf CLI: search/download/upload models, datasets. |
| `[ ]` | `jupyter-live-kernel` | `data-science` | Iterative Python via live Jupyter kernel (hamelnb). |
| `[ ]` | `llama-cpp` | `mlops/inference` | llama.cpp local GGUF inference + HF Hub model discovery. |
| `[ ]` | `obliteratus` | `mlops/inference` | OBLITERATUS: abliterate LLM refusals (diff-in-means). |
| `[ ]` | `outlines` | `mlops/inference` | Outlines: structured JSON/regex/Pydantic LLM generation. |
| `[ ]` | `segment-anything-model` | `mlops/models` | SAM: zero-shot image segmentation via points, boxes, masks. |
| `[ ]` | `serving-llms-vllm` | `mlops/inference` | vLLM: high-throughput LLM serving, OpenAI API, quantization. |
| `[ ]` | `unsloth` | `mlops/training` | Unsloth: 2-5x faster LoRA/QLoRA fine-tuning, less VRAM. |
| `[ ]` | `weights-and-biases` | `mlops/evaluation` | W&B: log ML experiments, sweeps, model registry, dashboards. |

### devops-kanban

Kanban orchestration, webhooks, Tailscale, home-node ops.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `kanban-orchestrator` | `devops` | Decomposition playbook + specialist-roster conventions + anti-temptation rules for an orchestrator profile routing work through Kanban. The "don't do the work yourself" rule and the basic lifecycle are auto-injected into every kanban worker's system prompt; this skill is the deeper playbook when you're specifically playing the orchestrator role. |
| `[ ]` | `kanban-task-creation` | `devops` | Use when Berker asks to post, put, make, create, or dispatch a Kanban card from a specific spec. Defaults parked/non-running unless explicit start/run/dispatch intent is present. |
| `[ ]` | `kanban-task-router` | `devops` | Route kanban tasks to the right profile based on complexity, domain, and tool requirements. Use this whenever creating a kanban card to set the correct assignee and skills. |
| `[ ]` | `kanban-worker` | `devops` | Pitfalls, examples, and edge cases for Hermes Kanban workers. The lifecycle itself is auto-injected into every worker's system prompt as KANBAN_GUIDANCE (from agent/prompt_builder.py); this skill is what you load when you want deeper detail on specific scenarios. |
| `[ ]` | `nixos-hermes-home-node` | `devops` | Plan and implement reproducible, hardened NixOS home-node deployments for Hermes Agent. |
| `[ ]` | `tailscale-private-networking` | `devops` | Use when setting up Tailscale/tailnet private networking on Linux or NixOS: auth-key enrollment, MagicDNS, Tailscale SSH, private dashboard/service access, Tailscale Serve, subnet routing, and exit-node/VPN behavior. |
| `[ ]` | `webhook-subscriptions` | `devops` | Webhook subscriptions: event-driven agent runs. |

### social

X/Twitter, Yuanbao, social platform operations.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `xurl` | `social-media` | X/Twitter via xurl CLI: post, search, DM, media, v2 API. |
| `[ ]` | `yuanbao` | `yuanbao` | Yuanbao (元宝) groups: @mention users, query info/members. |

### red-team

Jailbreak/red-team/eval-heavy tools and skills.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `godmode` | `red-teaming` | Jailbreak LLMs: Parseltongue, GODMODE, ULTRAPLINIAN. |

### misc-review

Uncategorized or needs manual classification/pruning.

| Decision | Skill | Original category/categories | Description |
|---|---|---|---|
| `[ ]` | `dogfood` | `dogfood` | Exploratory QA of web apps: find bugs, evidence, reports. |

## Tools by pruning bucket

### core

Always-needed operating kernel: local execution, files, memory, skills, web, todo, clarification.

| Decision | Tool | Toolset(s) | Schema tokens |
|---|---|---|---:|
| `[ ]` | `clarify` | `clarify` | 279 |
| `[ ]` | `execute_code` | `code_execution` | 660 |
| `[ ]` | `patch` | `file` | 354 |
| `[ ]` | `read_file` | `file` | 202 |
| `[ ]` | `search_files` | `file` | 372 |
| `[ ]` | `write_file` | `file` | 157 |
| `[ ]` | `memory` | `memory` | 463 |
| `[ ]` | `session_search` | `session_search` | 1,000 |
| `[ ]` | `skill_manage` | `skills` | 856 |
| `[ ]` | `skill_view` | `skills` | 194 |
| `[ ]` | `skills_list` | `skills` | 57 |
| `[ ]` | `process` | `terminal` | 272 |
| `[ ]` | `terminal` | `terminal` | 1,021 |
| `[ ]` | `todo` | `todo` | 288 |
| `[ ]` | `web_extract` | `web` | 157 |
| `[ ]` | `web_search` | `web` | 174 |

### coding

Code implementation/review/debugging, GitHub workflows, subagents.

| Decision | Tool | Toolset(s) | Schema tokens |
|---|---|---|---:|
| `[ ]` | `delegate_task` | `delegation` | 1,550 |

### setup-admin

Hermes/NixOS/dotfiles/profile/router/cron/admin operations.

| Decision | Tool | Toolset(s) | Schema tokens |
|---|---|---|---:|
| `[ ]` | `cronjob` | `cronjob` | 1,640 |

### research

Web/browser research, papers, knowledge bases, note lookup.

| Decision | Tool | Toolset(s) | Schema tokens |
|---|---|---|---:|
| `[ ]` | `browser_back` | `browser` | 44 |
| `[ ]` | `browser_click` | `browser` | 100 |
| `[ ]` | `browser_console` | `browser` | 190 |
| `[ ]` | `browser_get_images` | `browser` | 63 |
| `[ ]` | `browser_navigate` | `browser` | 198 |
| `[ ]` | `browser_press` | `browser` | 86 |
| `[ ]` | `browser_scroll` | `browser` | 78 |
| `[ ]` | `browser_snapshot` | `browser` | 163 |
| `[ ]` | `browser_type` | `browser` | 104 |
| `[ ]` | `browser_vision` | `browser` | 198 |

### productivity

Email, docs, calendars, PDFs, notes, spreadsheets, maps, task systems.

_No active tools currently assigned._

### communications

Sending messages/email/social-ish delivery workflows.

| Decision | Tool | Toolset(s) | Schema tokens |
|---|---|---|---:|
| `[ ]` | `send_message` | `messaging` | 347 |

### media

Audio/video/image/youtube/music/media analysis and generation.

| Decision | Tool | Toolset(s) | Schema tokens |
|---|---|---|---:|
| `[ ]` | `text_to_speech` | `tts` | 202 |
| `[ ]` | `video_analyze` | `video` | 170 |
| `[ ]` | `vision_analyze` | `vision` | 188 |

### creative-design

Diagrams, mockups, design systems, web artifacts, infographics.

_No active tools currently assigned._

### smart-home

Home Assistant, Hue, sensors, rooms, automation.

_No active tools currently assigned._

### gaming

Game servers, modpacks, emulator/game play automation.

_No active tools currently assigned._

### apple

Apple/macOS/iMessage/FindMy/Notes/Reminders/desktop control.

_No active tools currently assigned._

### mlops

LLM/ML training, inference, evals, HF, model serving.

_No active tools currently assigned._

### devops-kanban

Kanban orchestration, webhooks, Tailscale, home-node ops.

_No active tools currently assigned._

### social

X/Twitter, Yuanbao, social platform operations.

_No active tools currently assigned._

### red-team

Jailbreak/red-team/eval-heavy tools and skills.

| Decision | Tool | Toolset(s) | Schema tokens |
|---|---|---|---:|
| `[ ]` | `mixture_of_agents` | `moa` | 126 |

### misc-review

Uncategorized or needs manual classification/pruning.

_No active tools currently assigned._

## Obvious duplicate skill names

| Skill | Copies | Categories | Paths |
|---|---:|---|---|
| `arxiv` | 2 | `research` | `/home/hermes/.hermes/skills/research/arxiv/SKILL.md`<br>`/home/hermes/.hermes/skills/research/arxiv.bak/SKILL.md` |
| `comfyui` | 2 | `creative` | `/home/hermes/.hermes/skills/creative/comfyui/SKILL.md`<br>`/home/hermes/.hermes/skills/creative/comfyui.bak/SKILL.md` |
| `google-workspace` | 2 | `productivity` | `/home/hermes/.hermes/skills/productivity/google-workspace/SKILL.md`<br>`/home/hermes/.hermes/skills/productivity/google-workspace.bak/SKILL.md` |
| `himalaya` | 2 | `email` | `/home/hermes/.hermes/skills/email/himalaya/SKILL.md`<br>`/home/hermes/.hermes/skills/email/himalaya.bak/SKILL.md` |
| `kanban-orchestrator` | 2 | `devops` | `/home/hermes/.hermes/skills/devops/kanban-orchestrator/SKILL.md`<br>`/home/hermes/.hermes/skills/devops/kanban-orchestrator.bak/SKILL.md` |
| `kanban-worker` | 2 | `devops` | `/home/hermes/.hermes/skills/devops/kanban-worker/SKILL.md`<br>`/home/hermes/.hermes/skills/devops/kanban-worker.bak/SKILL.md` |
| `maps` | 2 | `productivity` | `/home/hermes/.hermes/skills/productivity/maps/SKILL.md`<br>`/home/hermes/.hermes/skills/productivity/maps.bak/SKILL.md` |
| `notion` | 2 | `productivity` | `/home/hermes/.hermes/skills/productivity/notion/SKILL.md`<br>`/home/hermes/.hermes/skills/productivity/notion.bak/SKILL.md` |
| `ocr-and-documents` | 2 | `productivity` | `/home/hermes/.hermes/skills/productivity/ocr-and-documents/SKILL.md`<br>`/home/hermes/.hermes/skills/productivity/ocr-and-documents.bak/SKILL.md` |
| `polymarket` | 2 | `research` | `/home/hermes/.hermes/skills/research/polymarket/SKILL.md`<br>`/home/hermes/.hermes/skills/research/polymarket.bak/SKILL.md` |

## Suggested first-pass default split

If Berker wants a simple pruning baseline:

- `core`: keep as normal default.
- `coding`, `setup-admin`, `research`, `productivity`: keep as common profile-gated domains.
- `media`, `creative-design`, `smart-home`, `gaming`, `apple`, `mlops`, `social`: keep only if actively useful; otherwise profile-gate or archive.
- `red-team`: keep isolated, never default.
- `misc-review`: manually classify before deleting anything.

## Next mechanical step

After Berker marks this file up, convert decisions into a declarative manifest table in dotfiles. Do not delete skills/tools directly from live homes; first make profile-gated manifests and verify smoke tests.
