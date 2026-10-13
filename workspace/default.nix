# Workspace: who you are in each folder, and signed commits.
#
#   everywhere    the "root" git profile (defined here)
#   ~/Work/…      a context's profile, e.g. "work" (defined by ~/Work/config, see contexts/)
#
# Every commit and tag is signed. Each Mac makes its own SSH signing key per profile in
# ~/.ssh on the first `config rebuild` (no passphrase, so AI agents can commit too; never
# in Nix or git) and trusts only its own keys locally. GitHub verifies commits from all
# your Macs once each Mac's key is uploaded: `config signing` shows and uploads them.
# Deeper folders win.
{
  config,
  lib,
  user,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.workspace;
  home = "/Users/${user.name}";

  profileModule =
    { name, ... }:
    {
      options = {
        directory = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "Work/acme";
          description = ''
            Folder under your home whose repos use this profile. `null` means the root
            profile: every repo not under another profile's folder.
          '';
        };
        name = mkOption {
          type = types.str;
          default = user.fullName;
        };
        email = mkOption {
          type = types.str;
          default = user.email;
        };
        github = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "ericgibb";
          description = ''
            GitHub account this profile's signing keys are uploaded to (one per Mac), so
            GitHub shows its commits as "Verified". Used by `config signing`.
          '';
        };
        signingKey = mkOption {
          type = types.str;
          default = "${home}/.ssh/git-signing-${name}";
          description = "Private SSH key used to sign. Created on rebuild if missing.";
        };
        settings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          example = {
            core.sshCommand = "ssh -i ~/.ssh/acme";
          };
          description = "Extra git settings applied only inside this profile's folder.";
        };
      };
    };

  root = lib.filterAttrs (_: p: p.directory == null) cfg.gitProfiles;
  rootProfile = lib.head (lib.attrValues root);
  scoped = lib.sort (a: b: lib.stringLength a.directory < lib.stringLength b.directory) (
    lib.attrValues (lib.filterAttrs (_: p: p.directory != null) cfg.gitProfiles)
  );
in
{
  options.workspace = {
    directories = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Folders under your home created on every rebuild.";
    };
    gitProfiles = mkOption {
      type = types.attrsOf (types.submodule profileModule);
      default = { };
      description = "Git identities, chosen automatically by the folder a repo lives in.";
    };
  };

  config = {
    assertions = [
      {
        assertion = lib.length (lib.attrNames root) == 1;
        message = "workspace.gitProfiles needs exactly one profile with directory = null (the root profile).";
      }
    ];

    # Work and other areas add their own profiles from their context repos.
    workspace.gitProfiles.root.github = lib.mkDefault (user.github or null);

    hm =
      { lib, pkgs, ... }:
      let
        keygen = lib.getExe' pkgs.openssh "ssh-keygen";
        profiles = lib.attrValues cfg.gitProfiles;
        names = lib.attrNames cfg.gitProfiles;
        assoc =
          var: f:
          "declare -A ${var}=(${
            lib.concatMapStrings (n: " [${n}]=${lib.escapeShellArg (f cfg.gitProfiles.${n})}") names
          } )\n";

        # The allowed-signers list, as a command: see signers.sh.
        gitSigners = pkgs.writeShellApplication {
          name = "git-signers";
          runtimeInputs = with pkgs; [
            curl
            jq
            openssh
            coreutils
          ];
          text =
            "PROFILES=(${lib.escapeShellArgs names})\n"
            + assoc "EMAIL" (p: p.email)
            + assoc "KEY" (p: p.signingKey)
            + assoc "GITHUB" (p: if p.github == null then "" else p.github)
            + assoc "WHERE" (p: if p.directory == null then "" else p.directory)
            + "ALLOWED=${home}/.config/git/allowed_signers\n"
            + builtins.readFile ./signers.sh;
        };
      in
      {
        home.packages = [ gitSigners ];

        programs.git = {
          settings.user = {
            inherit (rootProfile) name email;
          };

          # Sign every commit and tag with an SSH key.
          signing = {
            format = "ssh";
            key = rootProfile.signingKey;
            signByDefault = true;
          };
          settings.tag.forceSignAnnotated = true;
          settings.gpg.ssh.allowedSignersFile = "${home}/.config/git/allowed_signers";

          # Folder-scoped profiles, most specific last so it wins.
          includes = map (p: {
            condition = "gitdir/i:${home}/${p.directory}/"; # /i: macOS paths are case-insensitive
            contents = lib.recursiveUpdate {
              user = {
                inherit (p) name email;
                signingKey = p.signingKey;
              };
            } p.settings;
          }) scoped;
        };

        # Folders, missing signing keys, and the allowed-signers list that lets
        # `git log --show-signature` verify commits made on this Mac.
        home.activation.workspace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${lib.concatMapStrings (d: ''
            run mkdir -p ${lib.escapeShellArg "${home}/${d}"}
          '') (lib.unique cfg.directories)}

          run mkdir -p ${home}/.ssh ${home}/.config/git
          run chmod 700 ${home}/.ssh
          ${lib.concatMapStrings (p: ''
            if [[ ! -f ${lib.escapeShellArg p.signingKey} ]]; then
              verboseEcho "Creating git signing key ${p.signingKey}"
              run ${keygen} -q -t ed25519 -N "" \
                -C ${lib.escapeShellArg "${p.email} git signing (${baseNameOf p.signingKey})"} \
                -f ${lib.escapeShellArg p.signingKey}
            fi
          '') profiles}

          run ${lib.getExe gitSigners} write
        '';
      };
  };
}
