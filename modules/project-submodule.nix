{ lib, name, ... }: {
  options = {
    url = lib.mkOption {
      type = lib.types.str;
      description = "Git URL of the project repository (https:// or git@).";
      example = "https://github.com/owner/repo";
    };

    branch = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Branch to clone. Defaults to the repository's default branch.";
      example = "main";
    };

    shell = {
      enable = lib.mkEnableOption "devShell and direnv management for this project";

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        description = "Packages to make available in the dev shell.";
      };

      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Environment variables to set in the dev shell.";
        example = { DATABASE_URL = "postgres://localhost/mydb"; };
      };

      shellHook = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Shell commands to run on entering the dev shell.";
        example = ''echo "entering myproject dev shell"'';
      };

      autoAllow = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Automatically run `direnv allow` after writing .envrc.
          Use with care — direnv allow is a security decision.
        '';
      };

      outputName = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = ''
          Name of the devShells output in the system flake.
          Defaults to the project attribute name.
          Override if the flake output name differs from the project name.
        '';
      };
    };
  };
}
