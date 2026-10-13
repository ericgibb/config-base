# ~/config

A macOS setup, declared in one repo and organized by **domain**: shell, apps, CLI
tools, git, macOS, AI agents. Each domain folder says *what* you want; the tool that
makes it happen (nix-darwin, home-manager, Homebrew) is an implementation detail
inside it. Git history is the audit log, and any generation can be rolled back.

It's public and meant to be forked (see "Make it yours"). Anything private, such as
work tools, a work identity or personal-only apps, lives in separate private context
repos layered on top (see "Contexts").

## Goals

Every change to this repo has to keep all of these true. If one can't, stop and
decide it explicitly (and update this section) rather than letting it drift.

1. **Every Mac, one system.** Nothing in this repo names or describes a particular
   machine. Every Mac builds the same system; what differs between them comes only
   from the layers in goal 4.
2. **A new Mac is minutes of typing.** Install Nix, clone, one switch, connect
   GitHub. Anything a change needs on a new Mac is automated (in the build, activation
   or `config`), or, if it truly can't be, added to "Setting up on a new machine".
3. **Reproducible and recoverable.** Everything is declared here and pinned by
   `flake.lock`; nothing is installed or configured by hand beyond the one-time steps
   listed in setup. Lose a Mac and you lose nothing but its keys; any change can be
   rolled back.
4. **Customizable in layers, each with one home.**

   | Layer | For | Where | In git? |
   |---|---|---|---|
   | root | what every Mac and every area of life gets | `~/config` | this repo (public) |
   | context | one area (work, a client, personal-only things) | `~/<Area>/config`, nests | its own private repo |
   | machine-local | quick tweaks on one Mac | `~/.zshrc.local`, `~/.ssh/config.local`, `config contexts add` | no |

   A setting goes in the narrowest layer that covers everywhere it's needed, and in
   only one.
5. **Public base, private areas.** This repo is public. Nothing from work or a
   client, and nothing private, is committed here: no employer names, work emails,
   team apps, keys or code. Those go in context repos (`~/Work/config`,
   `~/Personal/config`). A Mac without `~/Work/config` has no trace of work.
6. **Secrets never enter git or the Nix store.** They live in 1Password (`op://`
   references only); private keys never leave the Mac that made them.
7. **Clear and explainable.** One concern per domain folder, one entry point
   (`config`), and `config` can always say where something on this Mac came from. A
   change updates this README and the `nix-config` skill in the same commit.
8. **Safe for agents.** Agents can change and commit (signed) unattended; they can't
   push, bypass signing or install imperatively, and each change is a reviewable commit.

Before committing a change, check:

- Does it mention a specific Mac, hostname or serial? → goal 1
- Does a new Mac need an extra step? → automate it, or document it (goal 2)
- Is it in the right layer, and only one? → goal 4
- Is any of it private, or specific to work or a client? Is it a secret? → context repo or 1Password (goals 5, 6)
- Does `config check` pass from a fresh clone, with no contexts present?
- Are the README and `nix-config` skill still accurate? → goal 7

## Layout

```
flake.nix              inputs, who you are (user), the system every Mac builds
system.nix             which domains every Mac gets, state versions

shell/                 the one zsh: aliases, history, prompt, fzf, zoxide
editor/                Zed (app, settings, Tokyo Night theme, $EDITOR)
projects/              per-project environments: direnv, `isolate` (how much of your shell a project sees)
apps/                  desktop apps you want (default.nix) + how they're installed (homebrew.nix)
cli/                   command-line tools from nixpkgs
workspace/             git identity per folder, signed commits, `config signing`
contexts/              context repos (~/Work/config …): how they're found and layered in
git/                   git defaults, delta, gh
macos/                 Dock, Finder, keyboard, text replacements, trackpad, Touch ID sudo, screenshots
ai/                    Claude Code and Codex from one source (Zed gets the MCP servers)
  AGENTS.md            global instructions → ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md
  skills/              → ~/.claude/skills, ~/.codex/skills
  agents/              Claude Code subagents → ~/.claude/agents
  hooks/               one shell-command guard used by all three agents
  keys.env             1Password references for vendor API keys (no secrets)
nix/                   Nix itself: daemon settings, cleanup, the `config` command

lib/user.nix           plumbing: your account, home-manager, the `hm.` shorthand
```

### How a domain is written

Every domain is one Nix module. Settings for the machine are written as-is;
settings for your home directory go under `hm.`:

```nix
# shell/default.nix
programs.zsh.enable = true;          # system: /etc/zshrc loads nix
hm.programs.zsh.enable = true;       # you: ~/.config/zsh/.zshrc
```

Where swapping the tool is plausible, the domain declares its own option and a
backend file translates it. `apps/default.nix` defines `apps.desktop = [ … ]`;
`apps/homebrew.nix` turns that into Homebrew casks, and is the only file that knows
Homebrew exists. A NixOS machine would import a different backend; the app list
wouldn't change. `macos/` has no such layer, since its settings only exist on a Mac.

## Make it yours

This repo is one person's setup, written to be forked:

1. Fork it on GitHub (or use it as a template), e.g. as `<you>/config-base`.
2. Edit `user` in `flake.nix`: your macOS short username (`whoami`), full name, email and
   GitHub username. That's the only place you're named; your git identity, your agents'
   "About me" and commit signing all come from it.
3. Go through `apps/default.nix` (apps), `macos/default.nix` (Dock, defaults, text
   replacements) and `ai/AGENTS.md` (your agents' instructions); change what you don't want.
4. Follow "Setting up on a new machine" with your fork's URL.

Keep private things out of your fork: work tools and your work identity go in
`~/Work/config`, personal-only things in `~/Personal/config`. Both are private repos;
`config context new ~/Work/config` scaffolds one (see "Contexts").

## Setting up on a new machine

Every Mac builds the same system from this repo; nothing in it names a machine, and a
new Mac adds nothing to it. What differs between Macs is which context repos exist on
each (see "Contexts"): a work Mac has `~/Work/config`, a personal one doesn't, so it
never gets work apps or the work identity. Examples below use this repo
(`ericgibb/config-base`); use your fork's.

### 1. Install the basics

```sh
xcode-select --install          # Command Line Tools: git, compilers
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh   # Nix (multi-user)
```

Open a new terminal afterwards so `nix` is on PATH. Use the official installer, not
Determinate's: nix-darwin manages the Nix daemon itself. Apple silicon only (nixpkgs
dropped Intel Macs in 26.11).

### 2. Clone this repo

It's public, so a plain clone works (Git comes with the Command Line Tools). The second
line makes later pushes go over SSH, through 1Password:

```sh
git clone https://github.com/ericgibb/config-base.git ~/config
git -C ~/config remote set-url origin git@github.com:ericgibb/config-base.git
```

### 3. First switch

Installs nix-darwin, Homebrew and the apps; takes a while. `sudo` can't find `nix` on
its own, so use the full path:

```sh
sudo -H /nix/var/nix/profiles/default/bin/nix --extra-experimental-features 'nix-command flakes' \
  run nix-darwin/master#darwin-rebuild -- switch -L --flake ~/config#aarch64-darwin
sudo chown -R "$USER":staff ~/config/.git   # the root-run switch can leave root-owned git objects
```

If it stops with *"Unexpected files in /etc"*, the Nix installer's files are in the
way. Move each file it lists aside (usually these two), then re-run the switch:

```sh
sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
```

Existing dotfiles in `~` (e.g. `~/.zshrc`) are renamed to `*.before-nix`. Open a new
terminal; from now on it's `config rebuild`.

### 4. Connect to GitHub

1. **1Password**: sign in, then Settings → Developer → *Use the SSH agent* and
   *Integrate with 1Password CLI*. Your GitHub SSH key syncs from your vault, so
   there's nothing to create: `ssh -T git@github.com` should greet you by username.
2. **Upload this Mac's signing key.** The first switch made one
   (`~/.ssh/git-signing-root`); GitHub shows this Mac's commits as "Verified" once it's
   on your account:
   ```sh
   gh auth login -p ssh -s admin:ssh_signing_key   # choose Skip when it offers to upload an SSH key
   config signing upload
   config signing                                  # root: ✓ on github.com/<you>
   ```

### 5. Add this Mac's contexts

Clone the private context repos this Mac should have, then `config rebuild`:

- **Personal** (private things for every Mac of yours): your personal repo at
  `~/Personal/config`.
- **Work** (on a work Mac): your work context repo at `~/Work/config`.

After the rebuild, run `config signing upload` once per new profile, with `gh` logged in
to that profile's GitHub account (`gh auth login`, `gh auth switch`).

Then the one-time manual steps below.

### One-time manual steps (can't be automated)

- **Claude Code**: run `claude` and log in. **Codex**: `codex login`.
- **MCP servers** (`ai.mcpServers`, e.g. a work context's): authorize each on first use.
  In Claude Code run `/mcp`; in Codex `codex mcp login <name>`; Zed prompts in its agent panel.
- **Zed**: global AI rules live in its Rules Library (UI), not a file; projects' `AGENTS.md` is read automatically.
  To use Claude Code or Codex inside Zed, install them from the ACP Registry in the agent panel.
- macOS may ask you to log out once for keyboard/trackpad defaults to apply.

### Working across machines

- **One repo, one `flake.lock`**, so every Mac runs the same versions of everything.
  Change something on any Mac: edit, `config check`, commit, `git push`. On the others:
  `git pull`, then `config rebuild`. `config` shows whether what's applied matches the repo.
- **Bump versions on one Mac only** (`config update`, commit `flake.lock`, push) and
  pull on the others. Updating on several at once gives you lock-file conflicts.
- **Pull before editing**, and keep commits small; `pull.rebase` is on, so diverging
  histories replay cleanly.
- **Where differences go**: there are no per-Mac files. Something for one area of your
  life goes in that context's repo (`~/Work/config`, `~/Personal/config`); quick, uncommitted tweaks go in
  `~/.zshrc.local`, `~/.ssh/config.local`, or this Mac's list of extra contexts
  (`config contexts add`).
- **Signing keys**: each Mac has its own and uploads it to GitHub (see "Workspace and
  git identities"). Retiring or losing a Mac: delete its signing key on GitHub
  (Settings → SSH and GPG keys).

## Daily use

| Command | What it does |
|---|---|
| `config` | Status: what's active, whether `~/config` matches it, where everything comes from |
| `config rebuild` | Apply the config (Touch ID prompt) |
| `config check` | Build without applying and show the package diff |
| `config update` | Bump all inputs (nixpkgs, home-manager …), then `config check` / `config rebuild` |
| `config generations` / `config rollback` | List / return to previous system generations |
| `config edit` | Open `~/config` in Zed |
| `config contexts` | Context repos on this machine and whether they're applied |
| `config contexts add <path>` / `remove <path>` | Change this machine's list (not in git) |
| `config context new <path>` | Start a context repo, e.g. `~/Work/config` |
| `config signing` | This Mac's signing key per profile, and whether GitHub has it |
| `config signing upload` | Add this Mac's keys to GitHub (with `gh`), so its commits show "Verified" |
| `config help` | All of the above |
| `config which <cmd>` | Where a command comes from (alias, function, package, layer) and what it shadows |
| `aikeys <cmd>` | Run `<cmd>` with API keys pulled from 1Password for that process only |
| `nix shell nixpkgs#<pkg>` | Try a tool without installing it |

Machine-local, uncommitted shell tweaks go in `~/.zshrc.local`.

## Adding things

Find the domain, edit its `default.nix`, run `config rebuild`:

- **Desktop app** → `apps/default.nix` (`apps.desktop`; names from `brew search --cask <name>`).
- **CLI tool** → `cli/default.nix` (`nix search nixpkgs <name>`). If home-manager has a
  `programs.<tool>` module, prefer it; it manages the tool's config file too.
- **Shell alias, env var, prompt** → `shell/`. **Git** → `git/`. **macOS setting** → `macos/`.
- **Text replacement** (type a shortcut + space, get a phrase) → `macos.textReplacements`
  in `macos/default.nix`. They appear in System Settings → Keyboard → Text Replacements;
  ones you add there by hand are left alone.
- **AI instruction / skill / subagent / hook / MCP server** → `ai/`. A context adds its
  own with `ai.instructions` (appended to every agent's global instructions) and
  `ai.mcpServers`.
- **A new domain** (e.g. `editor/`, `fonts/`): create `<name>/default.nix` and add
  `./<name>` to the imports in `system.nix`.

Every agent on this machine also has a `nix-config` skill describing exactly this,
so you can ask Claude Code, Codex or Zed's agent to make the change for you.

## Workspace and git identities

`workspace/default.nix` decides who you are in each folder:

| Folder | Git profile | Defined in |
|---|---|---|
| everywhere | `root`: `user.email` and `user.github` from `flake.nix` | `~/config` |
| `~/Work/…` | `work`: whatever the work context sets | `~/Work/config`, only on Macs that have it |

- Every commit and tag is signed (`commit.gpgSign`, `tag.gpgSign`). Agents are also
  blocked from bypassing it (`--no-gpg-sign`, `commit.gpgsign=false`).
- **A key per Mac and profile**: `~/.ssh/git-signing-<profile>`, created on the first
  `config rebuild`: ed25519, no passphrase, so agents can commit unattended. Never in
  Nix or git, never copied between Macs, so losing a Mac means deleting one key on GitHub.
- **Verification**: GitHub verifies commits from all your Macs ("Verified") once each
  Mac's key is on the profile's `github` account. Locally, `~/.config/git/allowed_signers`
  lists only this Mac's keys, so `git log --show-signature` recognizes commits made here
  and says "No principal matched" for your other Macs'. Nothing is downloaded.
- `config signing` shows each profile's key and whether GitHub has it;
  `config signing upload` adds this Mac's keys (with `gh`, which needs the
  `admin:ssh_signing_key` scope).
- Another identity (an employer, a client) belongs to a context. In its `module.nix`:
  `workspace.gitProfiles.<name> = { email = "…"; github = "…"; };`; its folder is the
  context's. The deepest folder wins, and a nested context starts from root's identity.
  Run `config` inside a repo to see which profile applies.

## Contexts

Things that belong to one area of your life (work apps, a client's git identity, a
team's tools) live in a **context repo** next to that area, not in `~/config`:

| Repo | Applies to | Committed where |
|---|---|---|
| `~/config` | everything, every context | this repo (public) |
| `~/Personal/config` | `~/Personal` | your private personal repo |
| `~/Work/config` | `~/Work` | its own repo (can be your employer's) |
| `~/Work/acme/config` | `~/Work/acme`, on top of Work | its own repo |

A context's scope is the folder its repo sits in, so contexts nest. `config rebuild`
looks for the two defaults (`contexts.search` in `contexts/default.nix`) plus a
machine-local list in `~/.config/config/contexts` (`config contexts add/remove`; never
committed). It skips what's missing, pins each repo at its current commit, and builds
everything into one system. Nothing about a context is ever written into `~/config`;
the build goes through a generated wrapper in `~/.local/state/config/`.

A context repo is a small flake (`config context new ~/Work/config` scaffolds one):

- `module.nix`: the same options as `~/config` (`apps.desktop`, `hm.home.packages`,
  `workspace.gitProfiles.<name>.email`, `ai.instructions`, `ai.mcpServers` …). Lists
  and instructions add to root's. Apps, MCP servers and instructions apply everywhere on
  that Mac; the git profile and shell layer only inside the context's folder.
- `flake.nix` `devShells`: the **shell layer** for the whole folder. `~/config` writes
  `~/Work/.envrc` to load it (and to chain to the parent context's), so every project
  below gets it through `source_up_if_exists`.
- Each context gets its own git profile for its folder, with a signing key per Mac;
  set its email and GitHub account in `module.nix`.

`config` shows each context and whether the applied commit matches the repo; inside a
folder it shows which context applies. Commit a context's changes in its own repo;
until you do, `config` says it was applied from uncommitted files.

## GitHub

`~/config` is a public repo and context repos are private; pushing to any of them uses
the same keys. Two kinds:

| Key | Lives in | Used for | Prompt |
|---|---|---|---|
| GitHub SSH key | 1Password (SSH agent), shared by all your Macs | push, pull, clone | Touch ID each time |
| `~/.ssh/git-signing-<profile>` | disk, one per Mac | signing commits | none, so agents can commit |

`git/default.nix` points SSH for `github.com` at the 1Password agent. Other hosts go
in `~/.ssh/config.local` (not managed; an older `~/.ssh/config` is kept as
`config.before-nix` on the first rebuild, so move anything you need from it).

One-time setup (already done; a new Mac only needs "Connect to GitHub" above):

1. 1Password → Settings → Developer → **Use the SSH agent**.
2. 1Password → New Item → **SSH Key** → Generate (Ed25519), name it "GitHub".
3. GitHub → Settings → SSH and GPG keys → **New SSH key**, type *Authentication*, paste
   its public key.
4. Signing keys: `gh auth login -p ssh -s admin:ssh_signing_key` (choose *Skip* when it
   offers to upload an SSH key), then `config signing upload`.
5. Test: `ssh -T git@github.com` (Touch ID, then a greeting with your username).

Agents never push unless you ask (`ai/AGENTS.md`), and the Touch ID prompt means you'd
see it if one tried.

## Project environments

Each project carries its own `flake.nix` (its tools, pinned by its own `flake.lock`)
and an `.envrc`; direnv loads it when you `cd` in. The `.envrc` sets how much of your
global setup the project sees:

| Level | `.envrc` | The project sees |
|---|---|---|
| inherit | `use flake` | your full shell, with the project's tools in front |
| isolated | `isolate` + `use flake` | the project's tools, a few kept basics (git, gh, nix, direnv, `config`, zed, claude, codex, op, eza, bat, fzf, zoxide), macOS base |
| bare | `isolate --bare` + `use flake` | the project's tools, `nix`, macOS base |
| pure | `nix develop -i -k HOME -k TERM -c <cmd>` | nothing from your shell (one-off check that the flake alone is enough) |

`isolate jq rg` keeps extra host tools. `isolate` also unsets toolchain variables
inherited from your shell (`PYTHONPATH`, `GOPATH`, `NODE_OPTIONS`, `HOMEBREW_*` …).
It's defined in `projects/isolate.sh`; on machines without it, `.envrc` falls back to inherit.
After it, `source_up_if_exists` adds the shell layers of the folders above (e.g. the
Work context's); delete that line for a project that should ignore them.

Start a project by asking an agent to use the `new-project` skill (default: isolated).
Run `config` inside a project to see its level and exactly which layers are on PATH.

## How the AI setup works

One source, rendered per vendor:

| Concern | Source | Claude Code | Codex CLI | Zed |
|---|---|---|---|---|
| Global instructions | `ai/AGENTS.md` + `ai.instructions` | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | Rules Library (UI, manual) |
| Skills | `ai/skills/*/SKILL.md` | `~/.claude/skills` | `~/.codex/skills` | via Claude Code / Codex in the agent panel |
| Subagents | `ai/agents/*.md` | `~/.claude/agents` | n/a | n/a |
| Shell guard hook | `ai/hooks/guard-shell.sh` | `PreToolUse` | `hooks.json` | via Claude Code / Codex |
| MCP servers | `ai.mcpServers` (contexts add theirs) | managed plugin | `config.toml` | `context_servers` (editor/) |
| API keys | 1Password via `ai/keys.env` | `aikeys` | `aikeys` | n/a |

The guard hook blocks a few things for every agent: `rm -rf` on `/` or `~`, force
pushes, `curl | sh`, `brew install` / `npm i -g`, and reading secrets with `op`.
Add rules in the `RULES` array.

Generated files are read-only links into the Nix store. Changing a setting in a
tool's UI won't stick; change it here instead. Skills and agents you add by hand
next to the managed ones are left alone.

## Why these choices

- **Casks for GUI apps.** 1Password must live in `/Applications` for browser and CLI
  integration, and several of these apps are missing or lag on darwin in nixpkgs.
  nix-homebrew pins Homebrew itself; casks track upstream, and the apps self-update.
- **`cleanup = "none"` for now.** Once every app you use is listed, set it to
  `"zap"` in `apps/homebrew.nix` and anything installed by hand is removed on rebuild.
- **No per-machine files.** Every Mac builds the same system; differences come from
  which context repos a Mac has. A new Mac is a clone and a switch, and machine names
  never end up in history.
- **A signing key per Mac, verified by GitHub.** Keys never leave the Mac that made
  them, so a lost Mac costs one key, and a signature says which Mac made the commit.
  Each Mac trusts only its own keys locally; GitHub's "Verified" covers the rest, so
  nothing per-Mac is committed or downloaded.
- **Domains over tool folders.** The common nix layout (`modules/darwin`, `modules/home`)
  sorts by which tool applies a setting. Sorting by purpose keeps one concern in one
  folder; the `hm.` alias is a standard module-system idiom (`mkAliasOptionModule`).
- **Codex from nixpkgs; Claude Code from Anthropic's Homebrew cask.** nixpkgs marks
  Claude Code unfree, so it's never prebuilt and must compile on each Mac (that build
  hung on the first install). Auto-updaters are off for both: Codex moves with
  `config update`, Claude Code with `brew upgrade --cask claude-code`.

## Ideas for next steps

- Secrets in the repo (encrypted): `sops-nix` or `agenix`.
- A terminal emulator managed here (`programs.ghostty`), fonts via `fonts.packages`.
