{ lib, pkgs, ... }:

let
  yaml = pkgs.formats.yaml { };

  simpleWorkerToolsets = [
    "terminal"
    "file"
  ];

  codexToolsets = [
    "terminal"
    "file"
    "code_execution"
    "web"
    "skills"
    "memory"
    "session_search"
    "todo"
    "clarify"
  ];

  plannerToolsets = [
    "terminal"
    "file"
    "code_execution"
    "skills"
    "memory"
    "session_search"
    "todo"
    "clarify"
  ];

  researchToolsets = [
    "web"
    "browser"
    "terminal"
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
    "code_execution"
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
    "code_execution"
    "skills"
    "memory"
    "session_search"
    "terminal"
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

  disabledHeavySkills = [
    "audiocraft"
    "axolotl"
    "comfyui"
    "dspy"
    "godmode"
    "huggingface-hub"
    "jupyter-live-kernel"
    "llama-cpp"
    "lm-evaluation-harness"
    "minecraft-modpack-server"
    "obliteratus"
    "openhue"
    "outlines"
    "pokemon-player"
    "segment-anything"
    "touchdesigner-mcp"
    "trl-fine-tuning"
    "unsloth"
    "vllm"
    "weights-and-biases"
    "yuanbao"
  ];

  disabledMediaCreativeSocial = disabledHeavySkills ++ [
    "all-creative"
    "all-media"
    "all-social"
  ];

  disabledProductivity = [
    "all-email"
    "all-productivity"
  ];

  disabledResearch = [
    "all-research"
    "arxiv"
    "blogwatcher"
    "llm-wiki"
    "polymarket"
  ];

  disabledCoding = [
    "all-autonomous-ai-agents"
    "all-github"
    "all-software-development"
    "claude-code"
    "codex"
    "opencode"
    "github-code-review"
    "github-pr-workflow"
    "subagent-driven-development"
    "test-driven-development"
  ];

  disabledDevHeavy = disabledMediaCreativeSocial ++ disabledCoding;

  cheapAux = {
    provider = "openrouter";
    model = "google/gemini-2.5-flash-lite";
  };

  baseSettings = {
    approvals.mode = "off";
    security.tirith_enabled = false;
    fallback_providers = [ cheapAux ];
    auxiliary = {
      compression = cheapAux;
      title_generation = cheapAux;
      vision = cheapAux;
      web_extract = cheapAux;
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
      creation_nudge_interval = 0;
      disabled = disabledDevHeavy;
    };
    toolsets = simpleWorkerToolsets;
  };

  profileSettings = rec {
    worker = workerBase // {
      model = {
        provider = "openrouter";
        default = "google/gemini-2.5-flash-lite";
      };
      agent = {
        max_turns = 12;
        reasoning_effort = "low";
      };
      terminal = workerBase.terminal // { timeout = 60; };
    };

    codex-worker = baseSettings // {
      model = {
        provider = "openai-codex";
        default = "gpt-5.5";
      };
      agent = {
        max_turns = 60;
        reasoning_effort = "medium";
      };
      memory = specialistMemory;
      compression = specialistCompression;
      skills = {
        creation_nudge_interval = 50;
        disabled = [
          "all-creative"
          "all-media"
          "all-social"
        ] ++ disabledProductivity ++ disabledResearch;
      };
      terminal = baseSettings.terminal // { timeout = 180; };
      toolsets = codexToolsets;
    };

    planner = baseSettings // {
      model = {
        provider = "openai-codex";
        default = "gpt-5.5";
      };
      agent = {
        max_turns = 35;
        reasoning_effort = "medium";
      };
      memory = specialistMemory;
      compression = specialistCompression;
      skills = {
        creation_nudge_interval = 50;
        disabled = disabledMediaCreativeSocial ++ disabledProductivity ++ disabledResearch ++ [
          "all-autonomous-ai-agents"
          "all-github"
        ];
      };
      terminal = baseSettings.terminal // { timeout = 120; };
      toolsets = plannerToolsets;
    };

    research-worker = baseSettings // {
      model = {
        provider = "openrouter";
        default = "deepseek/deepseek-chat-v3-0324";
      };
      agent = {
        max_turns = 45;
        reasoning_effort = "medium";
      };
      memory = specialistMemory;
      compression = specialistCompression;
      skills = {
        creation_nudge_interval = 50;
        disabled = disabledMediaCreativeSocial ++ disabledProductivity ++ disabledCoding;
      };
      terminal = baseSettings.terminal // { timeout = 120; };
      toolsets = researchToolsets;
    };

    productivity-worker = baseSettings // {
      model = {
        provider = "openrouter";
        default = "deepseek/deepseek-chat-v3-0324";
      };
      agent = {
        max_turns = 45;
        reasoning_effort = "medium";
      };
      memory = specialistMemory;
      compression = specialistCompression;
      skills = {
        creation_nudge_interval = 50;
        disabled = disabledMediaCreativeSocial ++ disabledResearch ++ disabledCoding;
      };
      terminal = baseSettings.terminal // { timeout = 120; };
      toolsets = productivityToolsets;
    };

    media-worker = baseSettings // {
      model = {
        provider = "openai-codex";
        default = "gpt-5.5";
      };
      agent = {
        max_turns = 80;
        reasoning_effort = "medium";
      };
      compression = broadCompression;
      memory = broadMemory;
      skills = {
        creation_nudge_interval = 50;
        disabled = disabledHeavySkills;
      };
      toolsets = mediaToolsets;
    };

    knowledge-curator = baseSettings // {
      model = {
        provider = "openrouter";
        default = "google/gemini-2.5-flash-lite";
      };
      agent.max_turns = 50;
      compression = broadCompression // { threshold = 0.12; };
      memory = broadMemory;
      skills = {
        creation_nudge_interval = 50;
        disabled = disabledHeavySkills;
      };
      toolsets = knowledgeToolsets;
    };

    session-indexer = profileSettings.knowledge-curator;
    wiki-linter = profileSettings.knowledge-curator;

    fallback-full = baseSettings // {
      model = {
        provider = "openai-codex";
        default = "gpt-5.5";
      };
      agent = {
        max_turns = 90;
        reasoning_effort = "medium";
      };
      compression = broadCompression;
      memory = broadMemory;
      skills = {
        creation_nudge_interval = 50;
        disabled = disabledHeavySkills;
      };
      terminal = baseSettings.terminal // { timeout = 240; };
      toolsets = fallbackFullToolsets;
    };
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

    codex-worker = {
      summary = "Coding and declarative Nix/Hermes configuration worker using the Codex subscription model.";
      tags = [ "coding" "debugging" "repo" "tests" "git" "github" "nixos" "dotfiles" "hermes" "profiles" "router" "toolsets" "providers" "services" "packages" ];
      use_for = [
        "software development, debugging, tests, refactors, repository edits"
        "NixOS/dotfiles/Hermes Agent config/profile/router/toolset/provider/service/package changes"
        "GitHub/PR work"
      ];
      avoid_for = [
        "image, video, audio, or other media generation"
        "pure wiki/session curation tasks that can use the cheaper knowledge-curator"
        "chat-only opinions or lightweight conversation that should stay on default"
      ];
      priority = 70;
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

  codeTouchingProfiles = [ "codex-worker" "planner" "fallback-full" ];

  profileSoulText = name: meta: ''
    # ${name} SOUL

    You are Otto running as the ${name} Hermes profile.

    Core invariants:
    - Otto is Berker's direct, sharp, high-autonomy AI collaborator. Be useful, non-corporate, and concise unless detail is needed.
    - Match Berker's language.
    - Verify claims with tools when correctness depends on live files, commands, current facts, git state, math, or system state.
    - This profile is Nix-managed from /home/hermes/dotfiles. Generated files under /home/hermes/.hermes/profiles/${name}/ are runtime outputs; do not edit runtime profile config as final state.
    - Profile purpose: ${meta.summary}

    ${lib.optionalString (lib.elem name codeTouchingProfiles) ''
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
  # so commands such as `codex-worker` and `knowledge-curator` live in
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
  '';
}
