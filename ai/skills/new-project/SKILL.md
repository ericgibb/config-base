---
name: new-project
description: Bootstrap a new project folder on this Mac with its own Nix dev environment, direnv activation, an isolation level from his global shell, and agent instructions. Use when asked to create, scaffold, start or bootstrap a new project, app, service, library or repo, or to add a dev environment to an existing folder.
---

# New project

Every project gets its own toolchain from its own `flake.nix` (pinned by its own
`flake.lock`), loaded by direnv when you `cd` in. The project chooses how much of
the user's global shell it can see. Templates are in `templates/` next to this file;
copy and fill them in rather than writing from scratch. Stack-specific packages and
settings are in `stacks.md`.

## 1. Settle the inputs (ask only for what's missing)

- **Name and location.** Work projects go in `~/Work/<name>`, where the work context's
  git profile (identity + signing key) and shell layer apply automatically. If it's
  unclear whether it's work, ask.
  Existing folder: add only the files that are missing, never overwrite.
- **Stack** (language, framework, package manager). See `stacks.md`.
- **Isolation level.** Default to **isolated** unless the user says otherwise:

| Level | `.envrc` | The project sees |
|---|---|---|
| inherit | `use flake` | Everything in the user's shell, with the devShell in front |
| **isolated** (default) | `isolate`, `source_up_if_exists`, `use flake` | The devShell, kept shell + agent basics (git, gh, nix, direnv, config, zed, claude, codex, op, eza, bat, fzf, zoxide), macOS base |
| bare | `isolate --bare`, `source_up_if_exists`, `use flake` | The devShell, `nix`, macOS base |
| pure | (a command, not a mode) | `nix develop -i -k HOME -k TERM -c <cmd>`: nothing from the shell; use to prove the flake alone is enough |

  `source_up_if_exists` adds the shell layer of the folder's context (e.g. `~/Work`'s);
  keep it unless the user wants the project independent of it.
  Extra host tools to keep go after `isolate`, e.g. `isolate jq rg`. Prefer adding
  the tool to the flake instead, so it's pinned and works for anyone.

## 2. Create the files

From `templates/`, filling every `<placeholder>`:

1. **`flake.nix`**: the stack's runtime/compiler, package manager, LSP, formatter,
   linter, plus any CLI the project's scripts call (`jq`, `rg`…). In isolated/bare
   mode, anything not listed here is not on PATH. Use `mkShellNoCC` unless the
   project compiles native code (then `mkShell`).
2. **`.envrc`**: from `templates/envrc`, set to the chosen level, plus the stack's
   project-local state exports from `stacks.md`.
3. **`AGENTS.md`**: from the template. What the project is, layout, commands,
   conventions idiomatic to the stack, the environment rules, and the standing
   instructions (keep README current, keep AGENTS.md short and current).
4. **`CLAUDE.md`**: exactly one line, `@AGENTS.md`. Codex and Zed read AGENTS.md directly.
5. **`README.md`**: what it is, setup, how to run and test. Short and complete.
6. **`.gitignore`**: `templates/gitignore` plus the stack's entries.

Principle for state: anything that changes behavior (installed tools, venvs,
GOPATH/CARGO_HOME bins, npm global prefix) lives in the project, under `.direnv/` or
the stack's usual folder. Pure download caches that are content-addressed (Go module
cache, uv/npm caches) may stay shared.

## 3. Pin, stage, load

```sh
cd <project>
git init -b main            # skip if already a repo
# Lock nixpkgs to the same revision ~/config uses: most packages are already downloaded.
nix flake lock --override-input nixpkgs \
  "github:NixOS/nixpkgs/$(jq -r .nodes.nixpkgs.locked.rev ~/config/flake.lock)"
git add -A                  # flakes only see tracked files
direnv allow
```

Do not run `direnv allow` on the user's behalf in a folder you didn't just create; ask.

## 4. Verify

- `direnv exec . <tool> --version` for the main toolchain binary.
- `config` from inside the folder: **This session** shows direnv active and the
  isolation level; **PATH** shows only `this session`, `project: kept host tools`
  and `macOS` layers when isolated.
- `nix develop -i -k HOME -k TERM -c <test or build command>` once, to prove the
  flake alone is enough (this is what CI or a teammate without this setup gets).

Then summarize what was created and the isolation level, and offer to make the
first commit with the `commit` skill. Never push.

## Changing level later

Edit the project's `.envrc` (add/remove `isolate`, `--bare`, kept tools); direnv
reloads on the next prompt. `isolate` comes from `~/config/projects/isolate.sh`;
on machines without it the `.envrc` falls back to inherit.
