this directory is for a project named prolix! a flake for managing your project library on a nix system.

there are mainly 2 parts to this project:

1. project pulling:
the user can declare their current projects, as attrsets with github urls attrs. then, on activation, the home manager pulls all project (if they do not exist already). the module also exposes an option like "baseDir" for the base of the project library. default is ~/dev/

2. nix-shell managment
for each project, the user can also configure a flake for a nix-shell with direnv. the script automatically puts a .envrc pointing to the flake of the project.
the user must be using flake-parts so that the system flake can also be moduled to have the nix-shell flake.

that way the user can declare the dev environment of each of their project for their main nixos config!
