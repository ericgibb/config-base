# Backend for `macos.textReplacements` (set in default.nix): writes them into macOS's own
# Text Replacements, the list in System Settings → Keyboard → Text Replacements. Current
# macOS has no `defaults` key for these, so text-replacements.sh edits the store the
# keyboard daemon reads, on every rebuild.
{ config, lib, ... }:
let
  cfg = config.macos.textReplacements;
  bad = lib.filterAttrs (s: p: lib.any (lib.hasInfix "\t") [ s p ] || lib.any (lib.hasInfix "\n") [ s p ]) cfg;
in
{
  options.macos.textReplacements = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    example = {
      omw = "On my way!";
    };
    description = ''
      macOS text replacements, shortcut → phrase. Typing the shortcut followed by a space
      or punctuation replaces it, in apps that use macOS text input (Notes, Mail, Messages,
      Safari, most native apps; not terminals or Zed). Replacements you add by hand in
      System Settings are left alone; ones removed from here are deleted on rebuild.
    '';
  };

  config = lib.mkIf (cfg != { }) {
    assertions = [
      {
        assertion = bad == { };
        message = "macos.textReplacements: shortcuts and phrases can't contain tabs or newlines.";
      }
    ];

    hm =
      { lib, pkgs, ... }:
      let
        entries = pkgs.writeText "text-replacements.tsv" (
          lib.concatStrings (lib.mapAttrsToList (s: p: "${s}\t${p}\n") cfg)
        );
        tool = pkgs.writeShellApplication {
          name = "text-replacements";
          runtimeInputs = [ pkgs.sqlite ];
          text = builtins.readFile ./text-replacements.sh;
        };
      in
      {
        home.activation.textReplacements = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${lib.getExe tool} ${entries}
        '';
      };
  };
}
