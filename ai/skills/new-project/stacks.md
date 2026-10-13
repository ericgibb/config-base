# Stack notes for new projects

Package names are nixpkgs attributes (check with `nix search nixpkgs <name>`). Pin a
major version with a versioned attribute (`nodejs_22`, `python312`, `go_1_25`) when
the project needs one; otherwise use the default attribute.

"State" lines go in `.envrc` **after** `use flake`. They keep anything that changes
behavior inside the project, so it can't leak between projects.

## TypeScript / Node

- **Packages:** `nodejs` (or `nodejs_22`), `pnpm`, `typescript-language-server`, `biome` (or `prettier`)
- **State:**
  ```sh
  export npm_config_prefix="$PWD/.direnv/npm-global"; PATH_add "$npm_config_prefix/bin"
  export COREPACK_HOME="$PWD/.direnv/corepack"
  PATH_add node_modules/.bin
  ```
- **.gitignore:** `node_modules/`, `dist/`, `coverage/`
- **Verify:** `direnv exec . node --version`; `pnpm install && pnpm test`

## Python

- **Packages:** `python3` (or `python312`), `uv`, `ruff`, `basedpyright`
- **State:** uv manages `.venv/` in the project; stop it downloading its own Python.
  ```sh
  export UV_PYTHON_DOWNLOADS=never
  export UV_PYTHON="$(command -v python3)"
  export VIRTUAL_ENV="$PWD/.venv"; PATH_add .venv/bin
  ```
- **.gitignore:** `.venv/`, `__pycache__/`, `.pytest_cache/`, `.ruff_cache/`, `dist/`
- **Verify:** `uv sync && uv run pytest`

## Go

- **Packages:** `go`, `gopls`, `golangci-lint`
- **State:** installed binaries are per project; the module download cache is shared.
  ```sh
  export GOPATH="$PWD/.direnv/go"; export GOBIN="$GOPATH/bin"; PATH_add "$GOBIN"
  export GOMODCACHE="${XDG_CACHE_HOME:-$HOME/.cache}/go-mod"
  export GOTOOLCHAIN=local   # never download a different Go than the flake's
  ```
- **.gitignore:** `/bin/`, `coverage.out`
- **Verify:** `go version && go test ./...`

## Rust

- **Packages:** `cargo`, `rustc`, `rust-analyzer`, `clippy`, `rustfmt` (use `pkgs.mkShell`
  if any crate builds C code)
- **State:**
  ```sh
  export CARGO_HOME="$PWD/.direnv/cargo"; PATH_add "$CARGO_HOME/bin"
  export RUST_SRC_PATH="$(rustc --print sysroot)/lib/rustlib/src/rust/library"
  ```
  Add `rustPlatform.rustLibSrc` to packages if rust-analyzer can't find std sources.
- **.gitignore:** `target/`
- **Verify:** `cargo --version && cargo test`

## Shell / tooling repos

- **Packages:** `shellcheck`, `shfmt`, `just`, plus every CLI the scripts call (`jq`, `ripgrep`, `curl`…)
- **.gitignore:** none extra
- **Verify:** `shellcheck scripts/*.sh`

## Anything else

Search nixpkgs for the runtime, package manager, language server and formatter.
Use the ecosystem's own config (for example `pyproject.toml`, `package.json`, `go.mod`)
for project dependencies. The flake provides tools, not libraries, unless they need
native build inputs (then use `mkShell` and add them to `buildInputs`).
