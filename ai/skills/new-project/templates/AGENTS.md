# <project name>

<One or two sentences: what this is and who it's for.>

## Layout

- `<dir>/`: <what lives here>

## Commands

All commands run inside the project environment (direnv loads it on `cd`; otherwise
prefix with `nix develop -c`).

- Install deps: `<command>`
- Run: `<command>`
- Test: `<command>`
- Lint / format: `<command>`

## Environment

- Toolchain comes only from `flake.nix`, pinned by `flake.lock`. Isolation level:
  **<inherit | isolated | bare>** (set in `.envrc`).
- If a command is missing, add its package to `flake.nix` `devShells.default.packages`.
  Do not install anything globally (`brew`, `npm -g`, `pip install --user`, `curl | sh`)
  and don't rely on tools that happen to be on the host.
- Behavior-changing state stays in the project (`.direnv/`, `<stack folder>`).
- Check that the flake alone is enough: `nix develop -i -k HOME -k TERM -c <test command>`.
- Secrets go in `.env.local` (gitignored). Never print, commit or read it unless asked.

## Conventions

- <Idioms for this stack: style, error handling, testing approach, naming.>

## Standing instructions

- Keep `README.md` current as living documentation when behavior, setup or commands change.
- Keep this file current as the project grows, but short: add what an agent needs to
  work here, remove what's no longer true, don't duplicate the README.
