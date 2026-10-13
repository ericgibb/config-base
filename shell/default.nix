# The one shell. Every terminal (Terminal, Zed, tmux, ssh-in) gets the
# same zsh, aliases, history, prompt and helpers from this file.
{ ... }:
{
  # System side: makes /etc/zshrc load the nix environment.
  programs.zsh.enable = true;

  hm =
    { config, ... }:
    {
      # EDITOR/VISUAL are set by editor/.
      home.sessionVariables = {
        PAGER = "less -FR";
        MANPAGER = "sh -c 'col -bx | bat -l man -p'";
      };

      home.sessionPath = [ "$HOME/.local/bin" ];

      home.shellAliases = {
        # eza also adds ls / ll / la / lt
        tree = "eza --tree";
        cat = "bat --paging=never";
        g = "git";
        gs = "git status -sb";
        ".." = "cd ..";
        "..." = "cd ../..";
      };

      programs.zsh = {
        enable = true;
        # Keep zsh files out of ~ (→ ~/.config/zsh).
        dotDir = "${config.xdg.configHome}/zsh";

        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        history = {
          size = 100000;
          save = 100000;
          path = "${config.xdg.dataHome}/zsh/history";
          share = true; # every open session sees commands from the others
          extended = true;
          ignoreDups = true;
          ignoreSpace = true; # prefix a command with a space to keep it out of history
          expireDuplicatesFirst = true;
        };

        initContent = ''
          setopt AUTO_CD INTERACTIVE_COMMENTS

          # Machine-local, untracked overrides (work secrets, experiments). Never committed.
          [[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
        '';
      };

      # Prompt
      programs.starship = {
        enable = true;
        settings = {
          add_newline = false;
          command_timeout = 1000;
          nix_shell.format = "via [$symbol$state]($style) ";
        };
      };

      programs.fzf.enable = true; # Ctrl-R history search, Ctrl-T file search
      programs.zoxide.enable = true; # `z <partial-dir-name>`
      programs.eza = {
        enable = true;
        git = true;
        extraOptions = [ "--group-directories-first" ];
      };
      programs.bat.enable = true;
    };
}
