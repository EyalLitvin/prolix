# my-projects.nix — the one file you write.
#
# Import this file in two places (no other code needed):
#
#   1. In your system flake's perSystem block:
#        perSystem = { pkgs, ... }: { imports = [ ./my-projects.nix ]; };
#
#   2. In your home-manager config:
#        imports = [ inputs.prolix.homeManagerModules.default ./my-projects.nix ];

{ pkgs, ... }: {
  prolix = {
    enable = true;

    # Where repos will be cloned. Supports ~.
    baseDir = "~/dev";

    # Path to your system flake. Used to generate .envrc files.
    # The .envrc will point to: <systemFlakePath>#devShells.<system>.<name>
    systemFlakePath = "~/.dotfiles";

    projects = {

      # A project with just repo pulling — no dev shell.
      my-website = {
        url = "https://github.com/owner/my-website";
      };

      # A project with repo pulling + a managed dev shell.
      my-backend = {
        url    = "https://github.com/owner/my-backend";
        branch = "main";

        shell = {
          enable = true;

          packages = with pkgs; [
            go
            gopls
            gotools
            postgresql
          ];

          env = {
            DATABASE_URL = "postgres://localhost/my_backend_dev";
            GO_ENV       = "development";
          };

          shellHook = ''
            echo "entering my-backend dev shell"
          '';

          # Set to true to run `direnv allow` automatically after writing .envrc.
          autoAllow = false;
        };
      };

      # A project where the devShell output name differs from the project attr name.
      legacy-app = {
        url = "git@github.com:owner/legacy-app.git";

        shell = {
          enable     = true;
          outputName = "legacy";  # points to devShells.<system>.legacy in system flake
          packages   = with pkgs; [ nodejs_20 yarn ];
        };
      };

    };
  };
}
