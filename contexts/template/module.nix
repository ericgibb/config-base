# @NAME@ context: settings added on top of ~/config by `config rebuild`.
# Same options as the root config; lists (apps, packages) combine with root's.
{ ... }:
{
  # Desktop apps only this context needs (Homebrew cask names).
  apps.desktop = [ ];

  # Git identity for ~/@DIRECTORY@. Defaults: root's name and email, and a signing
  # key per Mac (~/.ssh/git-signing-@NAME@). Set `github` to the account those keys
  # go on (`config signing upload`) so commits from all your Macs verify.
  # workspace.gitProfiles.@NAME@ = {
  #   email = "you@example.com";
  #   github = "your-github-username";
  # };

  hm = {
    # Command-line tools for this context, on PATH everywhere.
    # Prefer the shell layer in flake.nix for tools only needed inside ~/@DIRECTORY@.
    # home.packages = [ ];

    # Instructions for AI agents working anywhere under ~/@DIRECTORY@.
    # home.file."@DIRECTORY@/CLAUDE.md".source = ./CLAUDE.md;
  };
}
