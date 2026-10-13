# Global instructions for every AI agent

This file is the single source for Claude Code (`~/.claude/CLAUDE.md`) and
Codex (`~/.codex/AGENTS.md`). It is managed in `~/config/ai/AGENTS.md`; edit it
there and run `config rebuild`. An "About me" from `user` in `~/config/flake.nix` and
anything context repos add (`ai.instructions`) follow it. Repository-level `AGENTS.md` /
`CLAUDE.md` files add to it.

## How to work with me

- Be concise. Lead with the answer or the change, then the reasoning if it matters.
- Ask before anything destructive or hard to undo (deleting files, rewriting git
  history, force pushes, dropping data, changing shared infrastructure).
- Prefer small, reviewable changes. Don't refactor beyond what the task needs.
- When unsure about intent, ask one focused question instead of guessing.
- Run the project's own formatter, linter and tests before saying something is done.

## My machine

- macOS, configured declaratively with nix-darwin + home-manager in `~/config`.
- Don't install tools with `brew install`, `npm install -g`, `pip install --user`
  or curl-pipe-sh. Use `nix shell nixpkgs#<pkg>` for one-off tools, or propose a
  change to `~/config` (see the `nix-config` skill) for permanent ones. `~/config` is
  public: anything private or specific to one area (work, a client, personal-only) goes
  in that area's context repo (`~/Work/config`, `~/Personal/config`), never in `~/config`.
  Changes to `~/config` must keep the "Goals" in its README; if one can't, ask first.
- Per-project dependencies belong in the project's `flake.nix` + `.envrc`
  (`use flake`), not on the global system. New projects: use the `new-project`
  skill (default isolation: `isolate`, so only the flake's tools are on PATH).
- In a project, if a tool is missing, add it to that project's `flake.nix`;
  don't reach for a global install. Run `config` to see what a shell is getting.
- Secrets live in 1Password. Never print, log or commit secrets; never read
  `.env` files unless I ask.

## Git

- Conventional commits (`feat:`, `fix:`, `chore:` …), imperative mood, subject ≤ 72 chars.
- Never commit directly to `main` on shared repos; create a branch.
- Never push unless I ask.
- Every commit and tag is signed (SSH key chosen by folder; a context like `~/Work`
  has its own). Never bypass signing (`--no-gpg-sign`, `commit.gpgsign=false`); if signing
  fails, stop and tell me.
