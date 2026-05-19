{ lib, pkgs, ... }:

let
  yaml = pkgs.formats.yaml { };

  hermesRoutingPlugin = pkgs.stdenvNoCC.mkDerivation {
    pname = "hermes-routing-plugin";
    version = "0.1.0";
    src = ./plugins/routing;
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out/
      runHook postInstall
    '';
  };

  simpleWorkerToolsets = [
    "terminal"
    "file"
    "skills"
  ];

  codingToolsets = [
    "terminal"
    "file"
    "web"
    "skills"
    "memory"
    "session_search"
    "todo"
    "clarify"
  ];

  setupToolsets = [
    "terminal"
    "file"
    "web"
    "skills"
    "memory"
    "session_search"
    "todo"
    "clarify"
  ];

  plannerToolsets = [
    "file"
    "skills"
    "memory"
    "session_search"
    "todo"
    "clarify"
  ];

  researchToolsets = [
    "web"
    "browser"
    "file"
    "skills"
    "session_search"
    "memory"
    "clarify"
    "todo"
  ];

  productivityToolsets = [
    "terminal"
    "file"
    "web"
    "browser"
    "skills"
    "memory"
    "session_search"
    "clarify"
    "todo"
    "messaging"
  ];

  mediaToolsets = [
    "terminal"
    "file"
    "web"
    "browser"
    "vision"
    "image_gen"
    "video"
    "tts"
    "skills"
    "memory"
    "session_search"
    "clarify"
    "todo"
  ];

  knowledgeToolsets = [
    "file"
    "skills"
    "memory"
    "session_search"
    "terminal"
    "clarify"
    "todo"
  ];

  fallbackFullToolsets = [
    "web"
    "browser"
    "terminal"
    "file"
    "code_execution"
    "skills"
    "todo"
    "memory"
    "session_search"
    "clarify"
    "delegation"
    "cronjob"
    "messaging"
    "vision"
    "image_gen"
    "video"
    "tts"
  ];

  allProfileSkillNames = [
    "airtable"
    "apple-notes"
    "apple-reminders"
    "architecture-diagram"
    "arxiv"
    "ascii-art"
    "ascii-video"
    "audiocraft-audio-generation"
    "axolotl"
    "baoyu-comic"
    "baoyu-infographic"
    "blogwatcher"
    "claude-code"
    "claude-design"
    "codebase-inspection"
    "codex"
    "comfyui"
    "debugging-hermes-tui-commands"
    "declarative-email-on-nixos"
    "design-md"
    "dogfood"
    "dspy"
    "email-sending-workflows"
    "evaluating-llms-harness"
    "excalidraw"
    "findmy"
    "fine-tuning-with-trl"
    "gif-search"
    "github-auth"
    "github-code-review"
    "github-issues"
    "github-pr-workflow"
    "github-repo-management"
    "godmode"
    "google-workspace"
    "heartmula"
    "hermes-agent"
    "hermes-agent-skill-authoring"
    "hermes-dashboard-operations"
    "hermes-memory-configuration-audits"
    "hermes-profile-skill-management"
    "hermes-setup-improvement-implementer"
    "hermes-setup-improvement-research"
    "hermes-tui-debugging"
    "himalaya"
    "himalaya-calendar-invites"
    "huggingface-hub"
    "humanizer"
    "hyperframes"
    "hyperframes-design-systems"
    "ideation"
    "imessage"
    "jupyter-live-kernel"
    "kanban-orchestrator"
    "kanban-task-creation"
    "kanban-task-router"
    "kanban-worker"
    "linear"
    "llama-cpp"
    "llm-wiki"
    "locating-files"
    "macos-computer-use"
    "manim-video"
    "maps"
    "minecraft-modpack-server"
    "nano-pdf"
    "native-mcp"
    "nixos-hermes-home-node"
    "node-inspect-debugger"
    "notion"
    "obliteratus"
    "obsidian"
    "ocr-and-documents"
    "opencode"
    "openhue"
    "otto-email-signature"
    "otto-wiki"
    "outlines"
    "p5js"
    "pixel-art"
    "pokemon-player"
    "polymarket"
    "popular-web-designs"
    "powerpoint"
    "pretext"
    "profile-router"
    "python-debugpy"
    "requesting-code-review"
    "research-paper-writing"
    "segment-anything-model"
    "serving-llms-vllm"
    "sketch"
    "songsee"
    "songwriting-and-ai-music"
    "spike"
    "spotify"
    "subagent-driven-development"
    "sync-my-githubs"
    "systematic-debugging"
    "tailscale-private-networking"
    "teams-meeting-pipeline"
    "test-driven-development"
    "touchdesigner-mcp"
    "unsloth"
    "webhook-subscriptions"
    "weights-and-biases"
    "writing-plans"
    "xurl"
    "youtube-content"
    "youtube-metadata-inventories"
    "yuanbao"
  ];

  disableExcept = allowed: lib.subtractLists allowed allProfileSkillNames;

  workerSkillNames = [
    "kanban-orchestrator"
    "kanban-task-creation"
    "kanban-task-router"
    "kanban-worker"
  ];

  codingSkillNames = [
    "claude-code"
    "codebase-inspection"
    "codex"
    "debugging-hermes-tui-commands"
    "github-auth"
    "github-code-review"
    "github-issues"
    "github-pr-workflow"
    "github-repo-management"
    "hermes-agent-skill-authoring"
    "hermes-tui-debugging"
    "locating-files"
    "node-inspect-debugger"
    "opencode"
    "plan"
    "python-debugpy"
    "requesting-code-review"
    "spike"
    "subagent-driven-development"
    "systematic-debugging"
    "test-driven-development"
    "writing-plans"
  ];

  setupSkillNames = [
    "codebase-inspection"
    "debugging-hermes-tui-commands"
    "declarative-email-on-nixos"
    "email-sending-workflows"
    "github-auth"
    "github-repo-management"
    "hermes-agent"
    "hermes-agent-skill-authoring"
    "hermes-dashboard-operations"
    "hermes-memory-configuration-audits"
    "hermes-profile-skill-management"
    "hermes-setup-improvement-implementer"
    "hermes-setup-improvement-research"
    "hermes-tui-debugging"
    "himalaya"
    "kanban-orchestrator"
    "kanban-task-creation"
    "kanban-task-router"
    "kanban-worker"
    "locating-files"
    "native-mcp"
    "nixos-hermes-home-node"
    "otto-wiki"
    "plan"
    "profile-router"
    "spike"
    "sync-my-githubs"
    "systematic-debugging"
    "tailscale-private-networking"
    "webhook-subscriptions"
    "writing-plans"
  ];

  plannerSkillNames = [
    "kanban-orchestrator"
    "kanban-task-creation"
    "locating-files"
    "plan"
    "profile-router"
    "spike"
    "systematic-debugging"
    "writing-plans"
  ];

  researchSkillNames = [
    "arxiv"
    "blogwatcher"
    "llm-wiki"
    "locating-files"
    "maps"
    "obsidian"
    "otto-wiki"
    "polymarket"
    "research-paper-writing"
    "youtube-content"
    "youtube-metadata-inventories"
  ];

  productivitySkillNames = [
    "airtable"
    "apple-notes"
    "apple-reminders"
    "declarative-email-on-nixos"
    "email-sending-workflows"
    "findmy"
    "google-workspace"
    "himalaya"
    "himalaya-calendar-invites"
    "imessage"
    "linear"
    "locating-files"
    "macos-computer-use"
    "maps"
    "nano-pdf"
    "notion"
    "obsidian"
    "ocr-and-documents"
    "otto-email-signature"
    "powerpoint"
    "teams-meeting-pipeline"
    "xurl"
  ];

  mediaSkillNames = [
    "architecture-diagram"
    "ascii-art"
    "ascii-video"
    "baoyu-comic"
    "baoyu-infographic"
    "claude-design"
    "design-md"
    "excalidraw"
    "gif-search"
    "heartmula"
    "humanizer"
    "hyperframes"
    "hyperframes-design-systems"
    "ideation"
    "locating-files"
    "manim-video"
    "p5js"
    "pixel-art"
    "popular-web-designs"
    "pretext"
    "sketch"
    "songsee"
    "songwriting-and-ai-music"
    "spotify"
    "youtube-content"
    "youtube-metadata-inventories"
  ];

  knowledgeSkillNames = [
    "google-workspace"
    "hermes-memory-configuration-audits"
    "llm-wiki"
    "locating-files"
    "notion"
    "obsidian"
    "otto-wiki"
    "sync-my-githubs"
  ];

  fallbackSkillNames = allProfileSkillNames;

  cheapNous = {
    provider = "nous";
    model = "google/gemini-2.5-flash";
  };

  gemini3FlashNous = {
    provider = "nous";
    model = "google/gemini-3-flash-preview";
  };

  gemini3FlashFallback = gemini3FlashNous // {
    reasoning_effort = "medium";
  };

  codexSubscription = {
    provider = "openai-codex";
    model = "gpt-5.5";
  };

  sharedSkillDirs = [ "/home/hermes/.hermes/skills" ];

  profileToolSettings = toolsets:
    let
      exposedToolsets = lib.unique (toolsets ++ [ "routing" ]);
    in {
      plugins.enabled = [ "routing" ];
      toolsets = exposedToolsets;
      platform_toolsets.cli = exposedToolsets ++ [ "no_mcp" ];
      known_plugin_toolsets.cli = [ "routing" ];
    };

  baseSettings = {
    approvals.mode = "off";
    security.tirith_enabled = false;
    fallback_providers = [ cheapNous ];
    auxiliary = {
      compression = cheapNous;
      title_generation = cheapNous;
      vision = cheapNous;
      web_extract = cheapNous;
      triage_specifier = cheapNous;
      kanban_decomposer = cheapNous;
    };
    terminal = {
      backend = "local";
      cwd = "/home/hermes";
      timeout = 180;
    };
  };

  workerMemory = {
    memory_enabled = true;
    user_profile_enabled = false;
    memory_char_limit = 2000;
    user_char_limit = 1000;
    nudge_interval = 100;
  };

  specialistMemory = {
    memory_enabled = true;
    user_profile_enabled = true;
    memory_char_limit = 4000;
    user_char_limit = 2000;
    nudge_interval = 50;
  };

  highUseCodexMemory = specialistMemory // {
    memory_char_limit = 3200;
    user_char_limit = 1600;
    nudge_interval = 80;
  };

  broadMemory = specialistMemory // {
    memory_char_limit = 6600;
    user_char_limit = 4125;
  };

  workerCompression = {
    enabled = true;
    protect_last_n = 4;
    target_ratio = 0.15;
    threshold = 0.15;
  };

  specialistCompression = {
    enabled = true;
    protect_last_n = 6;
    target_ratio = 0.20;
    threshold = 0.30;
  };

  highUseCodexCompression = specialistCompression // {
    target_ratio = 0.15;
    threshold = 0.25;
  };

  broadCompression = {
    enabled = true;
    protect_last_n = 8;
    target_ratio = 0.20;
    threshold = 0.40;
  };

  workerBase = baseSettings // {
    compression = workerCompression;
    memory = workerMemory;
    skills = {
      external_dirs = sharedSkillDirs;
      creation_nudge_interval = 0;
      disabled = disableExcept workerSkillNames;
    };
  } // profileToolSettings simpleWorkerToolsets;

  profileSettings = rec {
    worker = workerBase // {
      model = {
        provider = cheapNous.provider;
        default = cheapNous.model;
      };
      agent = {
        max_turns = 12;
        reasoning_effort = "low";
      };
      terminal = workerBase.terminal // { timeout = 60; };
    };

    coding = baseSettings // {
      model = {
        provider = codexSubscription.provider;
        default = codexSubscription.model;
      };
      fallback_model = gemini3FlashFallback;
      fallback_providers = [ gemini3FlashFallback ];
      agent = {
        max_turns = 55;
        reasoning_effort = "medium";
      };
      memory = highUseCodexMemory;
      compression = highUseCodexCompression;
      skills = {
        external_dirs = sharedSkillDirs;
        creation_nudge_interval = 0;
        disabled = disableExcept codingSkillNames;
      };
      terminal = baseSettings.terminal // { timeout = 180; };
    } // profileToolSettings codingToolsets;

    setup-worker = baseSettings // {
      model = {
        provider = codexSubscription.provider;
        default = codexSubscription.model;
      };
      fallback_model = gemini3FlashFallback;
      fallback_providers = [ gemini3FlashFallback ];
      agent = {
        max_turns = 60;
        reasoning_effort = "medium";
      };
      memory = highUseCodexMemory;
      compression = highUseCodexCompression;
      skills = {
        external_dirs = sharedSkillDirs;
        creation_nudge_interval = 0;
        disabled = disableExcept setupSkillNames;
      };
      terminal = baseSettings.terminal // { timeout = 240; };
    } // profileToolSettings setupToolsets;

    planner = baseSettings // {
      model = {
        provider = cheapNous.provider;
        default = cheapNous.model;
      };
      agent = {
        max_turns = 35;
        reasoning_effort = "medium";
      };
      memory = specialistMemory;
      compression = specialistCompression;
      skills = {
        external_dirs = sharedSkillDirs;
        creation_nudge_interval = 0;
        disabled = disableExcept plannerSkillNames;
      };
      terminal = baseSettings.terminal // { timeout = 120; };
    } // profileToolSettings plannerToolsets;

    research-worker = baseSettings // {
      model = {
        provider = cheapNous.provider;
        default = cheapNous.model;
      };
      agent = {
        max_turns = 45;
        reasoning_effort = "medium";
      };
      memory = specialistMemory;
      compression = specialistCompression;
      skills = {
        external_dirs = sharedSkillDirs;
        creation_nudge_interval = 0;
        disabled = disableExcept researchSkillNames;
      };
      terminal = baseSettings.terminal // { timeout = 120; };
    } // profileToolSettings researchToolsets;

    productivity-worker = baseSettings // {
      model = {
        provider = gemini3FlashNous.provider;
        default = gemini3FlashNous.model;
      };
      fallback_model = gemini3FlashFallback;
      fallback_providers = [ gemini3FlashFallback ];
      agent = {
        max_turns = 45;
        reasoning_effort = "medium";
      };
      memory = specialistMemory;
      compression = specialistCompression;
      skills = {
        external_dirs = sharedSkillDirs;
        creation_nudge_interval = 0;
        disabled = disableExcept productivitySkillNames;
      };
      terminal = baseSettings.terminal // { timeout = 120; };
    } // profileToolSettings productivityToolsets;

    media-worker = baseSettings // {
      model = {
        provider = codexSubscription.provider;
        default = codexSubscription.model;
      };
      agent = {
        max_turns = 80;
        reasoning_effort = "medium";
      };
      compression = broadCompression;
      memory = broadMemory;
      skills = {
        external_dirs = sharedSkillDirs;
        creation_nudge_interval = 0;
        disabled = disableExcept mediaSkillNames;
      };
    } // profileToolSettings mediaToolsets;

    knowledge-curator = baseSettings // {
      model = {
        provider = cheapNous.provider;
        default = cheapNous.model;
      };
      agent.max_turns = 50;
      compression = broadCompression // { threshold = 0.30; };
      memory = broadMemory;
      skills = {
        external_dirs = sharedSkillDirs;
        creation_nudge_interval = 0;
        disabled = disableExcept knowledgeSkillNames;
      };
    } // profileToolSettings knowledgeToolsets;

    session-indexer = profileSettings.knowledge-curator;
    wiki-linter = profileSettings.knowledge-curator;

    fallback-full = baseSettings // {
      model = {
        provider = gemini3FlashNous.provider;
        default = gemini3FlashNous.model;
      };
      fallback_model = gemini3FlashFallback;
      fallback_providers = [ gemini3FlashFallback ];
      agent = {
        max_turns = 90;
        reasoning_effort = "medium";
      };
      compression = broadCompression;
      memory = broadMemory;
      skills = {
        external_dirs = sharedSkillDirs;
        creation_nudge_interval = 0;
        disabled = disableExcept fallbackSkillNames;
      };
      terminal = baseSettings.terminal // { timeout = 240; };
    } // profileToolSettings fallbackFullToolsets;
  };

  profileRouteMetadata = {
    worker = {
      summary = "Cheap, fast, read-mostly worker for local status checks, file inspection, simple scripts, and summaries.";
      tags = [ "cheap" "fast" "read-mostly" "status" "terminal" "files" "ports" "logs" ];
      use_for = [
        "file checks, ports, process/disk/service/log status, simple scripts, summaries"
        "quick local inspection that should not mutate code, config, services, packages, or profiles"
      ];
      avoid_for = [
        "coding, tests, refactors, repository edits"
        "NixOS config changes, Hermes config changes, profile/router edits, toolset/provider changes"
        "service/package mutations, web research, media, multi-step orchestration"
      ];
      priority = 60;
      fallback = false;
    };

    coding = {
      summary = "Project coding worker using the Codex subscription model for repos, tests, debugging, refactors, GitHub, and PR work.";
      tags = [ "coding" "debugging" "repo" "tests" "pytest" "git" "github" "pr" "pull-request" "branch" "commit" "software" "python" ];
      use_for = [
        "software development, project coding, debugging, tests, refactors, repository edits"
        "GitHub issues, branches, commits, pull requests, and code review"
      ];
      avoid_for = [
        "NixOS, dotfiles, machine setup, systemd, Tailscale, Hermes Agent config, profiles, router, toolsets, providers, services, packages, cronjobs"
        "image, video, audio, or other media generation"
        "pure wiki/session curation tasks that can use the cheaper knowledge-curator"
        "chat-only opinions or lightweight conversation that should stay on default"
      ];
      priority = 70;
      fallback = false;
    };

    setup-worker = {
      summary = "System setup worker for the Hermes machine: NixOS, dotfiles, Hermes config/profiles/router/toolsets/providers, services, cronjobs, Tailscale, packages, and declarative host behavior.";
      tags = [ "setup" "system" "nixos" "nix" "dotfiles" "flake" "home-manager" "hermes" "profiles" "router" "routing" "toolsets" "providers" "services" "systemd" "packages" "cron" "cronjob" "gateway" "dashboard" "tailscale" "machine" "config" ];
      use_for = [
        "NixOS, dotfiles, flakes, system packages, systemd services, timers, hardening, Tailscale, and host-level configuration"
        "Hermes Agent config, profiles, router, route_task, toolsets, providers, plugins, gateway, dashboard, cronjobs, and context/compression behavior"
        "anything that changes how the Hermes agent or its machine behaves"
      ];
      avoid_for = [
        "ordinary project coding, application features, repo refactors, tests, GitHub PR work unless the repo is the dotfiles/Hermes setup itself"
        "media generation"
        "pure wiki/session curation tasks that can use the cheaper knowledge-curator"
        "chat-only opinions or lightweight conversation that should stay on default"
      ];
      priority = 85;
      fallback = false;
    };

    planner = {
      summary = "Smart planning profile for implementation plans, architecture decomposition, and task breakdown.";
      tags = [ "planning" "architecture" "decomposition" "plan" "tasks" "kanban" ];
      use_for = [
        "implementation plans, architecture decomposition, task breakdown"
        "turning ambiguous work into ordered steps before execution"
      ];
      avoid_for = [
        "direct code/config mutation unless explicitly asked"
        "media generation"
        "current-facts web research"
      ];
      priority = 75;
      fallback = false;
    };

    research-worker = {
      summary = "Research worker for web, current facts, papers, markets, and domain reconnaissance.";
      tags = [ "research" "web" "browser" "current" "news" "papers" "arxiv" "market" "polymarket" "reconnaissance" ];
      use_for = [
        "web/current facts/news/papers/arxiv/polymarket/market/domain reconnaissance"
        "source-backed comparisons and current external lookups"
      ];
      avoid_for = [
        "coding or repo edits"
        "NixOS/Hermes config mutation"
        "media generation"
        "email/docs/calendar execution"
      ];
      priority = 75;
      fallback = false;
    };

    productivity-worker = {
      summary = "Productivity worker for email, docs, calendar, sheets, Notion, Airtable, Linear, PDFs, and reporting.";
      tags = [ "email" "calendar" "docs" "sheets" "notion" "airtable" "linear" "pdf" "reporting" "messaging" ];
      use_for = [
        "email/calendar/docs/sheets/notion/airtable/linear/pdf/reporting"
        "sending reports, maintaining productivity systems, and document workflows"
      ];
      avoid_for = [
        "coding or repo edits"
        "NixOS/Hermes config mutation"
        "media generation"
      ];
      priority = 75;
      fallback = false;
    };

    media-worker = {
      summary = "Media and creative production worker with vision, image, video, and TTS tools.";
      tags = [ "media" "creative" "image" "video" "audio" "tts" "vision" "design" ];
      use_for = [
        "image generation, visual design, diagrams, screenshots, vision analysis"
        "video, audio, TTS, music, GIFs, thumbnails, posters, creative media workflows"
        "browser-assisted visual QA or creative web artifact work"
      ];
      avoid_for = [
        "plain coding tasks with no visual or media component"
        "cheap one-command sysadmin tasks"
      ];
      priority = 80;
      fallback = false;
    };

    knowledge-curator = {
      summary = "Knowledge, memory, wiki, session, and note-curation worker.";
      tags = [ "knowledge" "wiki" "memory" "sessions" "notes" "curation" "index" ];
      use_for = [
        "wiki updates, memory hygiene, session summaries, knowledge-base indexing"
        "organizing notes, curating durable facts, reconciling old session context"
        "maintaining Otto knowledge docs under HERMES_HOME"
      ];
      avoid_for = [
        "media generation"
        "large application coding tasks"
      ];
      priority = 65;
      fallback = false;
    };

    session-indexer = {
      summary = "Specialized scheduled worker for indexing and summarizing Hermes session logs.";
      tags = [ "sessions" "index" "summaries" "scheduled" "knowledge" ];
      use_for = [
        "session indexing jobs, transcript summarization, search-index maintenance"
      ];
      avoid_for = [
        "interactive user tasks unless explicitly about session indexing"
      ];
      priority = 30;
      fallback = false;
    };

    wiki-linter = {
      summary = "Specialized scheduled worker for linting Otto wiki pages and knowledge docs.";
      tags = [ "wiki" "lint" "knowledge" "scheduled" ];
      use_for = [
        "wiki linting, contradiction scans, knowledge doc hygiene"
      ];
      avoid_for = [
        "interactive user tasks unless explicitly about wiki linting"
      ];
      priority = 30;
      fallback = false;
    };

    fallback-full = {
      summary = "Last-resort full-tool/full-skill profile for low-confidence unknown execution and cross-domain work.";
      tags = [ "fallback" "full" "general" "unknown" "cross-domain" ];
      use_for = [
        "low-confidence unknown execution"
        "cross-domain work that no narrower specialist confidently owns"
      ];
      avoid_for = [
        "chat-only opinions or lightweight conversation that should stay on default"
        "tasks clearly owned by a narrower cheaper specialist"
      ];
      priority = 95;
      fallback = true;
    };
  };

  renderList = xs: lib.concatMapStringsSep "\n" (x: "  - ${builtins.toJSON x}") xs;

  # PROFILE.md is generated from this route metadata during NixOS activation.
  # Do not hand-edit /home/hermes/.hermes/profiles/*/PROFILE.md; update
  # profileRouteMetadata here, rebuild, and let activation refresh runtime state.
  profileDocs = lib.mapAttrs
    (name: meta: pkgs.writeText "hermes-profile-${name}-PROFILE.md" ''
      ---
      name: ${builtins.toJSON name}
      summary: ${builtins.toJSON meta.summary}
      tags:
      ${renderList meta.tags}
      use_for:
      ${renderList meta.use_for}
      avoid_for:
      ${renderList meta.avoid_for}
      priority: ${toString meta.priority}
      fallback: ${if meta.fallback then "true" else "false"}
      ---

      # ${name}

      ${meta.summary}
    '')
    profileRouteMetadata;

  setupTouchingProfiles = [ "setup-worker" ];

  # Retired generated profiles. Keep their directories/state in place, but remove
  # generated routing/config files so dynamic router scans do not keep seeing
  # old profile names after a rename.
  retiredProfiles = [ "codex-worker" ];

  profileSoulText = name: meta: ''
    # ${name} SOUL

    You are Otto running as the ${name} Hermes profile.

    Core invariants:
    - Otto is Berker's direct, sharp, high-autonomy AI collaborator. Be useful, non-corporate, and concise unless detail is needed.
    - Match Berker's language.
    - Verify claims with tools when correctness depends on live files, commands, current facts, git state, math, or system state.
    - This profile is Nix-managed from /home/hermes/dotfiles. Generated files under /home/hermes/.hermes/profiles/${name}/ are runtime outputs; do not edit runtime profile config as final state.
    - Profile purpose: ${meta.summary}
    - Keep this profile's manifest small. If the task needs tools or skills outside this profile's role, route/escalate with `route_task` instead of expanding the job inline.

    ${lib.optionalString (lib.elem name setupTouchingProfiles) ''
    Declarative change rule:
    - Durable NixOS, Hermes, profile, router, toolset, model, provider, service, or package changes must be patched in /home/hermes/dotfiles and verified with an appropriate check/rebuild path. Do not treat edits to generated runtime profile files as final state.
    - Prefer Nix/declarative changes over imperative runtime mutation. For this environment, parent agents may run sudo nixos-rebuild switch after review; do not assume generated profile files are the source of truth.
    ''}
    ${lib.optionalString (name == "worker") ''
    Worker read-only rule:
    - Stay cheap and read-mostly. Use worker for status checks, file/log inspection, ports, processes, disk/service state, simple scripts, and summaries.
    - Avoid coding, NixOS/Hermes/profile/router config changes, service/package mutation, web research, media generation, and multi-step orchestration. If a request implies mutation, route/escalate instead of doing it here.
    ''}
  '';

  profileSouls = lib.mapAttrs
    (name: meta: pkgs.writeText "hermes-profile-${name}-SOUL.md" (profileSoulText name meta))
    profileRouteMetadata;

  profileConfigFiles = lib.mapAttrs
    (name: settings: yaml.generate "hermes-profile-${name}-config.yaml" settings)
    profileSettings;

  # One executable per profile is exposed through environment.systemPackages,
  # so commands such as `coding`, `setup-worker`, and `knowledge-curator` live in
  # /run/current-system/sw/bin after a rebuild. They intentionally do not depend
  # on ~/.local/bin aliases; /run/current-system/sw/bin is the canonical PATH
  # location for Nix-managed wrappers on hermesbox.
  profileWrappers = lib.mapAttrsToList
    (name: _:
      pkgs.writeShellApplication {
        name = name;
        text = ''
          exec /run/current-system/sw/bin/hermes --profile ${lib.escapeShellArg name} "$@"
        '';
      })
    profileSettings;

  hermesProfileRouter = pkgs.writeShellApplication {
    name = "hermes-profile-router";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      # Profile sessions set HERMES_HOME to their profile directory. The router
      # needs the shared Hermes home so it can read all generated PROFILE.md
      # files, not only the current profile's nested/nonexistent profiles dir.
      export HERMES_HOME=/home/hermes/.hermes
      exec ${pkgs.python3}/bin/python3 ${./scripts/hermes-profile-router.py} "$@"
    '';
  };
in
{
  environment.systemPackages = profileWrappers ++ [ hermesProfileRouter ];

  system.activationScripts.hermesProfiles.text = ''
    set -euo pipefail

    install -d -m 0755 -o hermes -g hermes /home/hermes/.hermes/profiles
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: configFile: ''
      install -d -m 0755 -o hermes -g hermes /home/hermes/.hermes/profiles/${lib.escapeShellArg name}
      install -m 0644 -o hermes -g hermes ${configFile} /home/hermes/.hermes/profiles/${lib.escapeShellArg name}/config.yaml
    '') profileConfigFiles)}
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: profileDoc: ''
      install -d -m 0755 -o hermes -g hermes /home/hermes/.hermes/profiles/${lib.escapeShellArg name}
      install -m 0644 -o hermes -g hermes ${profileDoc} /home/hermes/.hermes/profiles/${lib.escapeShellArg name}/PROFILE.md
    '') profileDocs)}
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: profileSoul: ''
      install -d -m 0755 -o hermes -g hermes /home/hermes/.hermes/profiles/${lib.escapeShellArg name}
      install -m 0644 -o hermes -g hermes ${profileSoul} /home/hermes/.hermes/profiles/${lib.escapeShellArg name}/SOUL.md
    '') profileSouls)}
    # Profiles use the shared skill store declared in skills.external_dirs.
    # Remove stale per-profile skill copies so they cannot shadow updated shared skills.
    ${lib.concatMapStringsSep "\n" (name: ''
      rm -rf /home/hermes/.hermes/profiles/${lib.escapeShellArg name}/skills
    '') ((lib.attrNames profileSettings) ++ retiredProfiles)}

    ${lib.concatMapStringsSep "\n" (name: ''
      install -d -m 0755 -o hermes -g hermes /home/hermes/.hermes/profiles/${lib.escapeShellArg name}/plugins
      ln -sfn ${hermesRoutingPlugin} /home/hermes/.hermes/profiles/${lib.escapeShellArg name}/plugins/nix-managed-hermes-routing-plugin
      chown -h hermes:hermes /home/hermes/.hermes/profiles/${lib.escapeShellArg name}/plugins/nix-managed-hermes-routing-plugin
    '') (lib.attrNames profileSettings)}

    ${lib.concatMapStringsSep "\n" (name: ''
      rm -f /home/hermes/.hermes/profiles/${lib.escapeShellArg name}/config.yaml \
        /home/hermes/.hermes/profiles/${lib.escapeShellArg name}/PROFILE.md \
        /home/hermes/.hermes/profiles/${lib.escapeShellArg name}/SOUL.md
    '') retiredProfiles}
  '';
}

