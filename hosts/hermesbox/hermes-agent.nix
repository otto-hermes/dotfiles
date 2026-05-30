{ config, hermes-agent, lib, pkgs, ... }:

{
  services.hermes-agent = {
    enable = true;
    createUser = false;
    user = "hermes";
    group = "hermes";

    # Keep the CLI and gateway on the same managed state directory.
    addToSystemPackages = true;
    stateDir = "/home/hermes";
    workingDirectory = "/home/hermes/workspace";
    extraDependencyGroups = [ "messaging" "fal" "firecrawl" ];

    environmentFiles = [
      # sops-decrypted env is the source of truth for secrets.
      # The legacy .keys/hermes.env has been retired — same content exists here.
      config.sops.secrets."hermes/env".path
      # Additional env (gitignored, not in sops): API_SERVER_KEY, etc.
      "/home/hermes/.hermes/.env.local"
    ];
    environment = {
      AGENT_BROWSER_EXECUTABLE_PATH = "/etc/profiles/per-user/hermes/bin/chromium-browser";
      WHATSAPP_ENABLED = "false";
    };

    mcpServers.nixos = {
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      timeout = 120;
      connect_timeout = 60;
    };

    settings =
      let
        defaultToolsets = [
          "web"
          "browser"
          "terminal"
          "file"
          "code_execution"
          "skills"
          "clarify"
          "todo"
          "memory"
          "session_search"
          "delegation"
          "cronjob"
          "messaging"
          "vision"
          "image_gen"
          "video"
          "video_gen"
          "x_search"
          "moa"
          "tts"
          "homeassistant"
          "spotify"
          "yuanbao"
          "computer_use"
          "no_mcp"
        ];
      in {
      web = {
        backend = "firecrawl";
        extract_backend = "firecrawl";
        search_backend = "firecrawl";
      };
      tools.tool_search = {
        # Progressive disclosure for MCP/plugin tools. Core Hermes tools stay
        # directly visible; large deferrable tool surfaces are replaced with
        # tool_search/tool_describe/tool_call once they exceed this threshold.
        enabled = "auto";
        threshold_pct = 10;
        search_default_limit = 5;
        max_search_limit = 20;
      };
      browser = {
        cloud_provider = "browser-use";
      };
      model = {
        # Primary: Kimi K2.6 via OpenRouter free tier (1000 req/day pool).
        provider = "openrouter";
        default = "moonshotai/kimi-k2.6:free";
      };
      # Fallback chain: remaining free models first, then fast paid Codex,
      # then OWL Alpha via Nous, then cheap DeepSeek paid as last resort.
      fallback_providers = [
        {
          provider = "openrouter";
          model = "minimax/minimax-m2.5:free";
        }
        {
          provider = "openrouter";
          model = "deepseek/deepseek-v4-flash:free";
        }
        {
          provider = "openai-codex";
          model = "gpt-5.5";
        }
        {
          provider = "nous";
          model = "openrouter/owl-alpha";
        }
        {
          provider = "nous";
          model = "deepseek/deepseek-v4-flash";
        }
      ];
      toolsets = defaultToolsets;
      agent = {
        max_turns = 90;
        reasoning_effort = "medium";
      };
      skills = {
        external_dirs = [ "/home/hermes/.hermes/skills" ];
        creation_nudge_interval = 15;
        disabled = [];
      };
      terminal = {
        backend = "local";
        cwd = "/home/hermes";
        timeout = 240;
      };
      memory = {
        nudge_interval = 10;
        memory_enabled = true;
        user_profile_enabled = true;
        memory_char_limit = 6600;
        user_char_limit = 4125;
      };
      compression = {
        enabled = true;
        threshold = 0.40;
        target_ratio = 0.20;
        protect_last_n = 8;
      };
      auxiliary = {
        compression = {
          provider = "nous";
          model = "deepseek/deepseek-v4-flash";
          fallback_chain = [
            { provider = "openrouter"; model = "moonshotai/kimi-k2.6:free"; }
            { provider = "openrouter"; model = "minimax/minimax-m2.5:free"; }
            { provider = "openrouter"; model = "deepseek/deepseek-v4-flash:free"; }
          ];
        };
        vision = {
          provider = "nous";
          model = "google/gemini-3-flash-preview";
          fallback_chain = [
            {
              provider = "nous";
              model = "google/gemini-2.5-flash";
            }
          ];
        };
        web_extract = {
          provider = "nous";
          model = "deepseek/deepseek-v4-flash";
          fallback_chain = [
            { provider = "openrouter"; model = "moonshotai/kimi-k2.6:free"; }
            { provider = "openrouter"; model = "minimax/minimax-m2.5:free"; }
            { provider = "openrouter"; model = "deepseek/deepseek-v4-flash:free"; }
          ];
        };
        title_generation = {
          provider = "nous";
          model = "deepseek/deepseek-v4-flash";
          fallback_chain = [
            { provider = "openrouter"; model = "moonshotai/kimi-k2.6:free"; }
            { provider = "openrouter"; model = "minimax/minimax-m2.5:free"; }
            { provider = "openrouter"; model = "deepseek/deepseek-v4-flash:free"; }
          ];
        };
        triage_specifier = {
          provider = "nous";
          model = "deepseek/deepseek-v4-flash";
          fallback_chain = [
            { provider = "openrouter"; model = "moonshotai/kimi-k2.6:free"; }
            { provider = "openrouter"; model = "minimax/minimax-m2.5:free"; }
            { provider = "openrouter"; model = "deepseek/deepseek-v4-flash:free"; }
          ];
        };
        kanban_decomposer = {
          provider = "nous";
          model = "deepseek/deepseek-v4-flash";
          fallback_chain = [
            { provider = "openrouter"; model = "moonshotai/kimi-k2.6:free"; }
            { provider = "openrouter"; model = "minimax/minimax-m2.5:free"; }
            { provider = "openrouter"; model = "deepseek/deepseek-v4-flash:free"; }
          ];
        };
      };
      cron = {
        script_timeout_seconds = 600;
      };
      approvals.mode = "off";
      security.tirith_enabled = false;
      unauthorized_dm_behavior = "pair";

      display = {
        show_reasoning = false;
        show_cost = true;
        sections.thinking = "collapsed";
        bell_on_complete = true;
      };

      stt = {
        enabled = true;
        provider = "openai";
      };

      tts = {
        # Use edge-tts as an external CLI instead of Hermes' built-in Python
        # provider. The built-in provider imports edge_tts into Hermes' sealed
        # Python 3.12 venv; edge-tts depends on aiohttp, which collides with
        # Hermes core deps and is intentionally rejected by the Nix wrapper.
        provider = "edge-cli";
        providers.edge-cli = {
          type = "command";
          command = "edge-tts --file {input_path} --voice {voice} --write-media {output_path}";
          output_format = "mp3";
          voice = "en-US-EmmaMultilingualNeural";
          voice_compatible = true;
        };
      };

      telegram = {
      };
      whatsapp = {
        bridge_script = "/home/hermes/.hermes/platforms/whatsapp/bridge/bridge.js";
      };
      platforms.whatsapp.extra.bridge_script = "/home/hermes/.hermes/platforms/whatsapp/bridge/bridge.js";
    };

    extraPackages = with pkgs; [
      curl
      espeak-ng
      fd
      ffmpeg
      git
      himalaya
      jq
      nodejs_22
      chromium
      mcp-nixos
      python312Packages.edge-tts
      ripgrep
      tree
      wget
    ];
  };

  systemd.services.hermes-agent = {
    serviceConfig = {
      # Hermes agents may run `sudo` in terminal commands (nixos-rebuild,
      # systemctl, git-as-root). NoNewPrivileges blocks privilege escalation
      # even from inside the service' own process tree, so we must disable it.
      NoNewPrivileges = lib.mkForce false;
      ProtectSystem = lib.mkForce false;
      TimeoutStopSec = "240s";
      UnsetEnvironment = [ "MESSAGING_CWD" ];
      ReadWritePaths = lib.mkAfter [
        "/home/hermes"
        "/home/hermes/.keys"
      ];
    };

    environment = {
      AGENT_BROWSER_EXECUTABLE_PATH = "/etc/profiles/per-user/hermes/bin/chromium-browser";
      HYPERFRAMES_BROWSER_PATH = "${pkgs.chromium}/bin/chromium";
      PRODUCER_HEADLESS_SHELL_PATH = "${pkgs.chromium}/bin/chromium";
      PRODUCER_FORCE_SCREENSHOT = "true";
      SHELL = lib.mkForce "${pkgs.bashInteractive}/bin/bash";
      WHATSAPP_ENABLED = lib.mkForce "false";
      API_SERVER_ENABLED = lib.mkForce "true";
      API_SERVER_HOST = lib.mkForce "127.0.0.1";
      API_SERVER_PORT = lib.mkForce "8642";
    };
  };
}
