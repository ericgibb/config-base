# Version control: git defaults, nicer diffs, GitHub CLI, how you reach GitHub.
# Identity and signing (who you are in which folder) live in workspace/.
{ ... }:
{
  hm =
    { pkgs, ... }:
    {
      # Git LFS (large files). The filters name plain `git-lfs` rather than a Nix store path
      # so they match what GitHub Desktop and `git lfs install` write; seeing them already
      # set, those tools don't try to rewrite this (read-only) git config.
      home.packages = [ pkgs.git-lfs ];

      programs.git = {
        enable = true;
        lfs = {
          enable = true;
          package = null; # installed above; keeps the filter command plain `git-lfs`
        };
        settings = {
          init.defaultBranch = "main";
          pull.rebase = true;
          push.autoSetupRemote = true;
          rebase.autoStash = true;
          fetch.prune = true;
          diff.algorithm = "histogram";
          merge.conflictStyle = "zdiff3";
          alias = {
            co = "checkout";
            sw = "switch";
            lg = "log --graph --oneline --decorate";
            amend = "commit --amend --no-edit";
          };
        };
        ignores = [
          ".DS_Store"
          ".direnv/"
          "result"
          ".env.local"
          ".claude/settings.local.json"
        ];
      };

      programs.delta = {
        enable = true;
        enableGitIntegration = true;
        options.navigate = true;
      };

      programs.gh = {
        enable = true;
        settings.git_protocol = "ssh";
      };

      # SSH to GitHub (push, pull, clone) authenticates with a key held in 1Password:
      # Touch ID approves each use, so agents can commit but can't push unnoticed.
      # Commit *signing* uses separate on-disk keys (workspace/). One-time setup is in
      # the README ("GitHub").
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        # Hosts you don't want in this repo go in ~/.ssh/config.local (not managed).
        includes = [ "config.local" ];
        settings."github.com" = {
          User = "git";
          IdentityAgent = ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"''; # quoted: the path has a space
        };
      };
    };
}
