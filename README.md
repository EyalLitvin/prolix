# prolix

Declarative project library management for NixOS. Define your repositories and their development environments once, in your system config — prolix takes care of cloning them and wiring up your shell automatically.

## What it does

prolix is a [Home Manager](https://github.com/nix-community/home-manager) module with two jobs:

**1. Project pulling**

You declare a list of git repositories in your config. Every time you run `home-manager switch`, prolix checks whether each repo exists on disk and clones any that are missing. If a repo already exists, it is left untouched — prolix never overwrites your work.

**2. Dev shell management**

For each project you can also declare a development shell: which tools should be available, which environment variables should be set, and what should run on entry. prolix writes a `.envrc` file into each project directory pointing [direnv](https://direnv.net/) at the shell you declared. When you `cd` into the project, direnv activates the shell automatically.

The shells themselves are proper [Nix flake](https://nixos.wiki/wiki/Flakes) outputs in your system flake — not hidden generated files. They live in your dotfiles alongside your NixOS config and are reproducible across machines.

---

## Prerequisites

- NixOS or nix with flakes and the `nix-command` experimental feature enabled
- [Home Manager](https://github.com/nix-community/home-manager) configured
- [flake-parts](https://github.com/hercules-ci/flake-parts) used as the structure for your system flake
- [direnv](https://direnv.net/) and [nix-direnv](https://github.com/nix-community/nix-direnv) installed and hooked into your shell (only needed for dev shell management)

If you are not using flake-parts yet, the repo pulling feature still works on its own without it.

---

## Installation

### Step 1 — Add prolix as a flake input

In your system `flake.nix`, add prolix to your inputs and follow its inputs to your own to avoid duplicate nixpkgs copies:

```nix
inputs = {
  nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
  flake-parts.url = "github:hercules-ci/flake-parts";
  home-manager    = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  prolix = {
    url = "github:owner/prolix";
    inputs.nixpkgs.follows     = "nixpkgs";
    inputs.home-manager.follows = "home-manager";
    inputs.flake-parts.follows  = "flake-parts";
  };
};
```

### Step 2 — Import the flake-parts module

In your flake's top-level `imports`, add the prolix flake-parts module. Then import your projects file inside `perSystem` so that `pkgs` is available:

```nix
outputs = inputs@{ flake-parts, prolix, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {

    imports = [ prolix.flakeModules.default ];  # <-- add this

    perSystem = { pkgs, ... }: {
      imports = [ ./my-projects.nix ];           # <-- and this
    };

    # ... rest of your flake
  };
```

### Step 3 — Import the Home Manager module

Wherever you define your Home Manager configuration, add the prolix HM module and the same projects file:

```nix
home-manager.users.alice = {
  imports = [
    inputs.prolix.homeManagerModules.default  # <-- add this
    ./my-projects.nix                          # <-- and this
    # ... your other HM modules
  ];
};
```

If you use a standalone `home-manager` configuration (not as a NixOS module):

```nix
homeConfigurations."alice" = home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  modules = [
    inputs.prolix.homeManagerModules.default
    ./my-projects.nix
  ];
};
```

### Step 4 — Write your projects file

Create `my-projects.nix` (the name is up to you). This is the **only file you write** — all your project configuration lives here:

```nix
{ pkgs, ... }: {
  prolix = {
    enable  = true;
    baseDir = "~/dev";   # all repos will be cloned under this directory
  };

  prolix.projects = {

    my-website = {
      url = "https://github.com/alice/my-website";
    };

  };
}
```

### Step 5 — Apply

```
home-manager switch
```

prolix will clone any declared repos that are missing. That's it.

---

## Dev shell management

To have prolix also manage your development environments, you need to:

1. Tell prolix where your system flake lives (so it can write `.envrc` files pointing to it)
2. Declare the shell for each project

### Declaring a shell

```nix
{ pkgs, ... }: {
  prolix = {
    enable          = true;
    baseDir         = "~/dev";
    systemFlakePath = "~/.dotfiles";  # path to your system flake
  };

  prolix.projects = {

    my-backend = {
      url = "https://github.com/alice/my-backend";

      shell = {
        enable = true;

        packages = with pkgs; [
          go
          gopls
          gotools
          postgresql
        ];

        env = {
          DATABASE_URL = "postgres://localhost/mydb_dev";
          GO_ENV       = "development";
        };

        shellHook = ''
          echo "entering my-backend"
        '';
      };
    };

  };
}
```

After running `home-manager switch`:

- The repo is cloned to `~/dev/my-backend`
- A `.envrc` is written there pointing to `~/.dotfiles#devShells.x86_64-linux.my-backend`
- Your system flake now has a `devShells.x86_64-linux.my-backend` output generated from the shell options above

When you `cd ~/dev/my-backend`, direnv activates the shell. You will be prompted to run `direnv allow` once (unless `autoAllow = true`).

### How the `.envrc` looks

prolix writes a single-line `.envrc`:

```bash
# managed by prolix — do not edit
use flake /home/alice/.dotfiles#devShells.x86_64-linux.my-backend
```

The file is only written if it does not already exist. If you delete it, prolix recreates it on the next `home-manager switch`. If you want to customise `.envrc` for a project, simply create the file yourself before running switch — prolix will leave it alone.

---

## All options

### Top-level options

| Option | Type | Default | Description |
|---|---|---|---|
| `prolix.enable` | `bool` | `false` | Enable prolix |
| `prolix.baseDir` | `str` | `"~/dev"` | Directory where repos are cloned. Supports `~`. |
| `prolix.systemFlakePath` | `str` | `""` | Path to your system flake. Required if any project has `shell.enable = true`. Supports `~`. |
| `prolix.projects` | `attrs` | `{}` | Attrset of projects (see below) |

### Per-project options (`prolix.projects.<name>.*`)

| Option | Type | Default | Description |
|---|---|---|---|
| `url` | `str` | required | Git URL of the repository. Accepts `https://` and `git@` formats. |
| `branch` | `str` or `null` | `null` | Branch to clone. Defaults to the repository's default branch. |
| `shell.enable` | `bool` | `false` | Enable dev shell and `.envrc` management for this project. |
| `shell.packages` | `[package]` | `[]` | Packages to make available in the dev shell. |
| `shell.env` | `{ str = str; }` | `{}` | Environment variables to set in the dev shell. |
| `shell.shellHook` | `str` | `""` | Commands to run when entering the dev shell. |
| `shell.autoAllow` | `bool` | `false` | Run `direnv allow` automatically after writing `.envrc`. |
| `shell.outputName` | `str` | `<name>` | Name of the `devShells` output in the system flake. Defaults to the project attribute name. |

---

## Common patterns

### Private repos via SSH

Use the `git@` URL format, which authenticates via your SSH agent:

```nix
my-private-repo = {
  url = "git@github.com:alice/private-repo.git";
};
```

### Cloning a specific branch

```nix
my-project = {
  url    = "https://github.com/alice/my-project";
  branch = "develop";
};
```

### Custom devShell output name

If your flake output name needs to differ from the project attribute name (for example, because of naming constraints):

```nix
legacy-app = {
  url = "https://github.com/alice/legacy-app";
  shell = {
    enable     = true;
    outputName = "legacy";   # devShells.<system>.legacy in the flake
    packages   = with pkgs; [ nodejs_20 yarn ];
  };
};
```

### Auto-allowing direnv

If you trust the generated `.envrc` and want the shell to activate immediately without a manual `direnv allow`:

```nix
my-project = {
  url = "https://github.com/alice/my-project";
  shell = {
    enable    = true;
    autoAllow = true;
    packages  = with pkgs; [ rustc cargo ];
  };
};
```

### Repo only, no dev shell

Projects do not need a shell. Declaring `url` is enough to have prolix clone the repo:

```nix
dotfiles-reference = {
  url = "https://github.com/alice/dotfiles-reference";
};
```

---

## How it works (internals)

prolix consists of two Nix modules that work together:

**`flakeModules.default`** (imported into your system flake)

Adds a `prolix.*` option namespace to the [flake-parts](https://github.com/hercules-ci/flake-parts) `perSystem` evaluation context. Reads `prolix.projects` and generates a `devShells.<name>` flake output for each project where `shell.enable = true`. This is what makes the dev shell a real, reproducible flake output that direnv can load.

**`homeManagerModules.default`** (imported into your Home Manager config)

Adds the same `prolix.*` option namespace to the Home Manager evaluation context. Registers two [activation scripts](https://nix-community.github.io/home-manager/index.xhtml#sec-activation-script) that run on every `home-manager switch`:

- `prolixClone` — clones any declared repo that does not exist at `<baseDir>/<name>`
- `prolixEnvrc` — writes a `.envrc` into each shell-enabled project directory (if the file does not already exist)

Your `my-projects.nix` file is valid in both module contexts — it sets the same `prolix.*` options, and each module reads the values it cares about.

---

## Troubleshooting

**`prolix: systemFlakePath must be set`**

You have `shell.enable = true` on at least one project but have not set `prolix.systemFlakePath`. Add the path to your system flake:

```nix
prolix.systemFlakePath = "~/.dotfiles";
```

**A repo was not cloned**

prolix only clones if the target directory does not exist. Check whether `<baseDir>/<name>` already exists (even as an empty directory). If you want prolix to manage it, remove the directory and run `home-manager switch` again.

**direnv does not activate after switching**

Run `direnv allow` once in the project directory. If you want this automated, set `shell.autoAllow = true` in the project options.

**The `.envrc` was not updated after I changed shell options**

prolix does not overwrite an existing `.envrc`. Delete the file and run `home-manager switch` to regenerate it.

**`error: attribute 'prolix' missing` in the flake context**

Make sure `prolix.flakeModules.default` is in the top-level `imports` of your flake-parts `mkFlake` call, and that your projects file is imported inside `perSystem`, not at the top level.
