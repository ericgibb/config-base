---
name: nix-config
description: Change this Mac's setup in ~/config (nix-darwin + home-manager). Use when asked to install or remove an app or CLI tool, change a macOS setting, shell alias, git setting, or any AI agent instruction, skill, hook or MCP server.
---

# Changing the machine config

Everything on this Mac is declared in `~/config`. Never install software
imperatively (`brew install`, `npm i -g`, `curl | sh`); edit the right file below,
then ask the user to run `config rebuild` (it needs sudo / Touch ID).

**Read the "Goals" section of `~/config/README.md` first.** Every change must keep all
of them (one system for every Mac, nothing machine-named, easy new-Mac setup, settings
in exactly one layer, nothing work-specific or secret in the repo, docs updated in the
same commit). If a request would break one, say which and ask the user before doing it;
don't work around it quietly. Run through the checklist under "Goals" before committing.

## Where things go

The repo is organized by domain. Each folder's `default.nix` is the place to edit;
machine-level settings are written directly, home-directory settings under `hm.`.

| Want to change | File |
|---|---|
| Desktop app | `apps/default.nix` (`apps.desktop`, Homebrew cask names) |
| Editor: Zed settings, theme, extensions, `$EDITOR` | `editor/default.nix` (`hm.programs.zed-editor`) |
| CLI program that must come from Homebrew (vendor build) | `apps/default.nix` (`apps.cli`) |
| Mac App Store app | `apps/default.nix` (`apps.appStore`) |
| How apps get installed (Homebrew options) | `apps/homebrew.nix` |
| CLI tool from nixpkgs | `cli/default.nix` (`hm.home.packages`) |
| Shell alias, env var, zsh option, prompt | `shell/default.nix` |
| direnv, per-project isolation (`isolate`, kept host tools) | `projects/` |
| Root git identity, commit signing (`config signing`) | `workspace/` (`workspace.gitProfiles`, `signers.sh`) |
| Git defaults, aliases, delta, gh | `git/default.nix` |
| macOS preference (Dock, Finder, keyboard …) | `macos/default.nix` |
| macOS text replacement (shortcut → phrase) | `macos/default.nix` (`macos.textReplacements`) |
| Nix settings; the `config` command (status, rebuild, check, update, rollback) | `nix/` (`default.nix`, `config.sh`) |
| Global agent instructions | `ai/AGENTS.md` |
| Skill for all agents | `ai/skills/<name>/SKILL.md` |
| Claude Code subagent | `ai/agents/<name>.md` |
| Shell-command guard rules | `ai/hooks/guard-shell.sh` (`RULES` array) |
| MCP server (`ai.mcpServers`) / agent settings | `ai/default.nix` |
| How context repos are found and layered in | `contexts/` (`contexts.search`, `template/`) |
| Anything only for one area (work apps, a client identity, team tools) | That context's repo, e.g. `~/Work/config/module.nix`, never `~/config` |
| Anything private that every Mac should still get | `~/Personal/config/module.nix` (private), never `~/config` |
| Which domains every Mac gets, state versions | `system.nix` |
| Username / email / GitHub account | `flake.nix` (`user`) |

Work-specific or proprietary settings never go in `~/config` (a public repo):
put them in the context repo for that folder (`config contexts` lists them; create one
with `config context new ~/Work/config`). A context's `module.nix` takes the same
options as `~/config`; commit it in that repo.

There are no per-machine files: every Mac builds the same system, and what differs
comes from the context repos present on it. New concern that fits no domain: create
`<domain>/default.nix` and add `./<domain>` to the `imports` in `system.nix`. Keep
tool-specific details (Homebrew, nix-darwin-only options) out of a domain's interface
where a different tool could do the job.

## Finding names

- What's active right now and where it came from: run `config` (generations, whether
  the repo matches what's applied, nix settings layers, shell files, PATH layers) and
  `config which <cmd>` (which package/layer a command comes from, what it shadows).

- nixpkgs package: `nix search nixpkgs <term>` or https://search.nixos.org/packages
- home-manager option (e.g. `programs.<tool>`): https://home-manager-options.extranix.com
- nix-darwin option: https://nix-darwin.github.io/nix-darwin/manual/
- Homebrew cask: `brew search --cask <term>`
- Prefer a home-manager `programs.<tool>` module over a bare package when one
  exists; it manages the tool's config file too.

## Workflow

1. Make the edit. Keep the existing comment style; one item per line in lists.
2. `nix fmt` from `~/config`.
3. Validate without activating: `config check` (builds and shows the package diff).
4. Tell the user to run `config rebuild`. If it fails, read the error from the bottom up;
   the first `error:` line after the trace is usually the real cause.
5. Commit with a conventional message (e.g. `feat(apps): add slack`).

## Rolling back

`config rollback` returns to the previous generation; `config generations` lists them.
