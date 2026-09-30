# Documentation tooling

`build.nix` builds the module reference from NixOS options, module READMEs, and repository runbooks. It is called by `flake.nix`, rather than imported as a NixOS module.

- `scripts/` contains Markdown processing, option splitting, search indexing, link checking, and browser JavaScript.
- `templates/` contains the Markdown page templates.
- `assets/` contains HTML templates and stylesheets.
- `tests/` contains the Python regression tests.

Run `nix develop --command just docs` to build the site, or `nix build .#checks.x86_64-linux.module-docs-check` to build and validate it. `just check` runs the Python tests along with repository lint checks.
