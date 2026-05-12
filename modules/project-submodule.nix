{ lib, name, ... }: {
  options = {
    url = lib.mkOption {
      type        = lib.types.str;
      description = "Git URL of the project repository (https:// or git@).";
      example     = "https://github.com/owner/repo";
    };

    branch = lib.mkOption {
      type        = lib.types.nullOr lib.types.str;
      default     = null;
      description = "Branch to clone. Defaults to the repository's default branch.";
      example     = "main";
    };

    shell = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "devShell and direnv management for this project";

          drv = lib.mkOption {
            type        = lib.types.nullOr lib.types.package;
            default     = null;
            description = "The dev shell derivation. Typically the result of pkgs.mkShell { ... }.";
            example     = lib.literalExpression "pkgs.mkShell { packages = [ pkgs.go ]; }";
          };

          autoAllow = lib.mkOption {
            type        = lib.types.bool;
            default     = false;
            description = ''
              Automatically run `direnv allow` after writing .envrc.
              Use with care — direnv allow is a security decision.
            '';
          };

          outputName = lib.mkOption {
            type        = lib.types.str;
            default     = name;
            description = ''
              Name of the devShells output in the system flake.
              Defaults to the project attribute name.
              Override if the flake output name differs from the project name.
            '';
          };
        };
      };
      default     = {};
      description = "Dev shell configuration for this project.";
    };
  };
}
