{ lib, flake-parts-lib, ... }:

{
  options.perSystem = flake-parts-lib.mkPerSystemOption ({ config, pkgs, lib, ... }:
    let
      cfg = config.prolix;
    in {
      options.prolix = {
        # Mirrors the HM module option so the user's my-projects.nix is valid
        # in both the HM and perSystem evaluation contexts.
        enable = lib.mkEnableOption "prolix dev shell generation";

        baseDir = lib.mkOption {
          type        = lib.types.str;
          default     = "~/dev";
          description = "Ignored in the flake-parts context. Declared for compatibility with the HM module.";
        };

        systemFlakePath = lib.mkOption {
          type        = lib.types.str;
          default     = "";
          description = "Ignored in the flake-parts context. Declared for compatibility with the HM module.";
        };

        projects = lib.mkOption {
          type        = lib.types.attrsOf (lib.types.submodule (import ./project-submodule.nix));
          default     = {};
          description = "Projects whose dev shells will be generated as flake outputs.";
        };
      };

      config = lib.mkIf cfg.enable {
        devShells =
          let
            shellProjects  = lib.filterAttrs (_: p: p.shell.enable) cfg.projects;

            missingDrv     = lib.attrNames (lib.filterAttrs (_: p: p.shell.drv == null) shellProjects);
            hasMissingDrv  = missingDrv != [];

            outputNames    = lib.mapAttrsToList (_: p: p.shell.outputName) shellProjects;
            hasDuplicates  = lib.length outputNames != lib.length (lib.unique outputNames);
          in
          lib.throwIf hasMissingDrv
            "prolix: the following projects have shell.enable = true but shell.drv is null: ${lib.concatStringsSep ", " missingDrv}"
            (lib.throwIf hasDuplicates
              "prolix: duplicate shell.outputName values detected — each project's outputName must be unique"
              (lib.mapAttrs' (_: project:
                lib.nameValuePair project.shell.outputName project.shell.drv
              ) shellProjects));
      };
    }
  );
}
