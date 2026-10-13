# AI agents: one source of truth, rendered for each vendor.
#
#   AGENTS.md           → ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md
#   skills/             → ~/.claude/skills, ~/.codex/skills
#   agents/             → ~/.claude/agents
#   hooks/              → one guard script, wired into Claude Code and Codex
#   ai.mcpServers       → Claude Code and Codex (and Zed, via editor/)
#   keys.env            → API keys pulled from 1Password on demand (`aikeys <cmd>`)
#
# Context repos add to `ai.instructions` and `ai.mcpServers` (e.g. a work context adds
# its team's MCP servers), so nothing private has to live here.
#
# Edit files in this folder, then `config rebuild`. Everything lands as read-only links into
# the nix store, so git history of this repo is the audit log for agent behavior.
{
  config,
  lib,
  user,
  ...
}:
let
  cfg = config.ai;
in
{
  options.ai = {
    instructions = lib.mkOption {
      type = lib.types.lines;
      description = ''
        Global instructions for every agent (~/.claude/CLAUDE.md, ~/.codex/AGENTS.md):
        AGENTS.md, then an "About me" from `user`, then whatever contexts add.
      '';
    };
    mcpServers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      example = {
        linear.url = "https://mcp.linear.app/mcp";
      };
      description = ''
        MCP servers for Claude Code, Codex and Zed. Remote servers authenticate with OAuth
        on first use (no secrets stored); for a local one that needs a token, use
        `env.TOKEN.file = "/path/to/secret";`.
      '';
    };
  };

  config = {
    # Claude Code itself comes from Anthropic's Homebrew cask: nixpkgs marks it unfree,
    # so it's never prebuilt and has to build on each Mac (that build hung here).
    # Its configuration below is still fully managed by nix.
    apps.cli = [ "claude-code" ];

    ai.instructions = lib.mkMerge [
      (lib.mkOrder 500 (builtins.readFile ./AGENTS.md))
      (lib.mkOrder 600 ''
        ## About me

        - I'm ${user.fullName} (${user.email}), GitHub `${user.github}`.
      '')
    ];

    hm =
      { lib, pkgs, ... }:
      let
        # One guard hook, three output dialects (see hooks/guard-shell.sh).
        guard = pkgs.writeShellApplication {
          name = "ai-guard-shell";
          runtimeInputs = [ pkgs.jq ];
          text = builtins.readFile ./hooks/guard-shell.sh;
        };
        guardCmd = vendor: "${lib.getExe guard} ${vendor}";
      in
      {
        programs.mcp = {
          enable = true;
          servers = cfg.mcpServers;
        };

        # ── Claude Code ───────────────────────────────────────────────────────
        programs.claude-code = {
          enable = true;
          package = null; # installed via apps.cli above
          enableMcpIntegration = true;
          context = cfg.instructions;
          skills = ./skills;
          agentsDir = ./agents;
          settings = {
            # Nix pins the version; the built-in updater would fight it.
            env.DISABLE_AUTOUPDATER = "1";
            permissions.deny = [
              "Read(./.env)"
              "Read(./.env.*)"
              "Read(./secrets/**)"
            ];
            hooks.PreToolUse = [
              {
                matcher = "Bash";
                hooks = [
                  {
                    type = "command";
                    command = guardCmd "claude";
                  }
                ];
              }
            ];
          };
        };

        # ── OpenAI Codex CLI ──────────────────────────────────────────────────
        programs.codex = {
          enable = true;
          enableMcpIntegration = true;
          context = cfg.instructions;
          skills = ./skills;
          settings = {
            approval_policy = "on-request";
            sandbox_mode = "workspace-write";
            check_for_update_on_startup = false;
          };
          hooks.PreToolUse = [
            {
              matcher = "^Bash$";
              hooks = [
                {
                  type = "command";
                  command = guardCmd "codex";
                  timeout = 10;
                }
              ];
            }
          ];
        };

        # Zed (editor/) gets the same MCP servers through programs.mcp. Running Claude Code
        # or Codex inside Zed's agent panel uses their own ~/.claude and ~/.codex setup
        # above (instructions, skills, hooks).

        # ── Vendor API keys ───────────────────────────────────────────────────
        # keys.env holds only op:// references, never secrets. `aikeys <cmd>` resolves
        # them through the 1Password CLI for that one process. Interactive CLIs normally
        # use their own login (`claude`, `codex login`), so this is for scripts/SDKs.
        xdg.configFile."ai/keys.env".source = ./keys.env;
        programs.zsh.initContent = ''
          aikeys() { op run --env-file="$HOME/.config/ai/keys.env" -- "$@"; }
        '';

        home.packages = [ guard ];
      };
  };
}
