# Editor: Zed as the daily IDE and the default $EDITOR.
#
# The app comes from Zed's own signed, self-updating build (via apps/). Its settings are
# managed here: on every `config rebuild`, the keys below are merged into
# ~/.config/zed/settings.json and win; anything else you change in Zed's UI is kept.
{ ... }:
{
  apps.desktop = [ "zed" ];

  hm = {
    programs.zed-editor = {
      enable = true;
      package = null; # installed by apps/ (Homebrew cask), not nixpkgs

      # Installed by Zed on first launch. Names: https://github.com/zed-industries/extensions
      extensions = [
        "tokyo-night" # "Tokyo Night Themes": Tokyo Night, Storm, Moon, Light
        "nix" # syntax + language server for ~/config and project flakes
      ];

      # MCP servers from ai/ (`ai.mcpServers`, contexts' too) show up in Zed's agent panel.
      enableMcpIntegration = true;

      userSettings = {
        # Follows macOS light/dark (macos/ switches it automatically by time of day).
        theme = {
          mode = "system";
          light = "Tokyo Night Light";
          dark = "Tokyo Night";
        };

        # No "Sign In" button in the title bar.
        title_bar.show_sign_in = false;

        # Project environments: use each folder's direnv/flake (projects/) for
        # language servers, tasks and the terminal.
        load_direnv = "shell_hook";
      };
    };

    home.sessionVariables = {
      EDITOR = "zed --wait";
      VISUAL = "zed --wait";
    };
  };
}
