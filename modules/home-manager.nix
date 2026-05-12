{ config, lib, pkgs, ... }:

let
  cfg = config.prolix;

  git    = lib.getExe pkgs.git;
  direnv = lib.getExe pkgs.direnv;

  # Resolve a path that may start with ~ using the known home directory.
  expandTilde = path:
    if lib.hasPrefix "~" path
    then config.home.homeDirectory + lib.removePrefix "~" path
    else path;

  baseDir         = expandTilde cfg.baseDir;
  systemFlakePath = expandTilde cfg.systemFlakePath;

  # Activation script: clone missing project repos.
  cloneScript = lib.concatStrings (lib.mapAttrsToList (name: project:
    let
      branchFlag = lib.optionalString (project.branch != null)
        "--branch ${lib.escapeShellArg project.branch} ";
    in ''
      (
        _prolix_dir=${lib.escapeShellArg "${baseDir}/${name}"}
        if [ ! -d "$_prolix_dir" ]; then
          echo "prolix: cloning ${name}..."
          $DRY_RUN_CMD ${git} clone ${branchFlag}${lib.escapeShellArg project.url} "$_prolix_dir"
        fi
      )
    ''
  ) cfg.projects);

  # Activation script: write (or update) .envrc for projects with shell management enabled.
  envrcScript = lib.concatStrings (lib.mapAttrsToList (name: project:
    lib.optionalString project.shell.enable (
      let
        flakeLine = "use flake ${systemFlakePath}#devShells.${pkgs.stdenv.hostPlatform.system}.${project.shell.outputName}";
      in ''
        (
          _prolix_dir=${lib.escapeShellArg "${baseDir}/${name}"}
          _prolix_envrc="$_prolix_dir/.envrc"
          if [ -d "$_prolix_dir" ]; then
            _prolix_write=0
            if [ ! -f "$_prolix_envrc" ]; then
              _prolix_write=1
            elif grep -qF "# managed by prolix" "$_prolix_envrc"; then
              if ! grep -qF ${lib.escapeShellArg flakeLine} "$_prolix_envrc"; then
                _prolix_write=1
              fi
            fi
            if [ "$_prolix_write" = "1" ]; then
              if [ -z "''${DRY_RUN_CMD:-}" ]; then
                echo "prolix: writing .envrc for ${name}..."
                printf '%s\n' \
                  ${lib.escapeShellArg "# managed by prolix — do not edit"} \
                  ${lib.escapeShellArg flakeLine} \
                  > "$_prolix_envrc"
                ${lib.optionalString project.shell.autoAllow ''
                  ${direnv} allow "$_prolix_dir"
                ''}
              else
                echo "prolix: would write .envrc for ${name}"
              fi
            fi
          fi
        )
      ''
    )
  ) cfg.projects);

in {
  options.prolix = {
    enable = lib.mkEnableOption "prolix project library management";

    baseDir = lib.mkOption {
      type        = lib.types.str;
      default     = "~/dev";
      description = "Base directory where projects will be cloned.";
      example     = "~/projects";
    };

    systemFlakePath = lib.mkOption {
      type    = lib.types.str;
      default = "";
      description = ''
        Absolute path to the user's system flake (e.g. their dotfiles repo).
        Used to generate .envrc files that point to devShells outputs.
        Supports ~ expansion.
      '';
      example = "/home/user/.dotfiles";
    };

    projects = lib.mkOption {
      type        = lib.types.attrsOf (lib.types.submodule (import ./project-submodule.nix));
      default     = {};
      description = "Projects to manage.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.systemFlakePath != "" || !lib.any (p: p.shell.enable) (lib.attrValues cfg.projects);
        message   = "prolix: `systemFlakePath` must be set when any project has `shell.enable = true`.";
      }
      {
        assertion = cfg.systemFlakePath == ""
                 || lib.hasPrefix "/" cfg.systemFlakePath
                 || lib.hasPrefix "~" cfg.systemFlakePath;
        message   = ''prolix: `systemFlakePath` must be an absolute path (starting with / or ~), got: "${cfg.systemFlakePath}".'';
      }
    ];

    home.activation.prolixClone = lib.hm.dag.entryAfter [ "writeBoundary" ] cloneScript;
    home.activation.prolixEnvrc = lib.hm.dag.entryAfter [ "prolixClone"   ] envrcScript;
  };
}
