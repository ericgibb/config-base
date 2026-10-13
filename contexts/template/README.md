# @NAME@ context

Extends `~/config` for everything under `~/@DIRECTORY@`. This repo is separate on
purpose: nothing in it is committed to the personal `~/config` repo.

| File | What it does |
|---|---|
| `module.nix` | Settings added to the system: apps, git identity, agent instructions |
| `flake.nix` | The shell layer (`devShells.default`) loaded in `~/@DIRECTORY@` |

Apply changes with `config rebuild` (new files must be `git add`ed first; uncommitted
changes are used with a warning). See which commit is active with `config contexts`.
