# Documentation tooling

`build.nix` builds the module reference from NixOS options, module READMEs, and repository runbooks. It is called by `flake.nix`, rather than imported as a NixOS module.

- `scripts/` contains Markdown processing, option splitting, search indexing, link checking, and browser JavaScript.
- `templates/` contains the Markdown page templates.
- `assets/` contains HTML templates and stylesheets.
- `tests/` contains the Python regression tests.

Run `nix develop --command just docs` to build the site, or `nix build .#checks.x86_64-linux.module-docs-check` to build and validate it. `just check` runs the Python tests along with repository lint checks.

Run `just docs-serve` in the development shell to preview at http://127.0.0.1:8000/; pass a port to override it. HTTP previews support search and sandboxed browsers such as Flatpak Firefox.

Each module declares its documentation `title`, `summary`, and `category` in `default.nix`. Deployment runbooks declare page metadata in `modules/deployment/documentation.nix`. Both feed one page inventory for sidebar grouping, README link rewriting, and rendering; only module pages append options.

Profile pages are derived from the registry through `profiles/documentation.nix`. The overview includes the generated `userProfiles` option reference; role pages use the same pipeline without option sections.

`options.nix` declares the shared `moduleDocumentation` attribute set using `metadata-type.nix`; modules supply metadata as configuration. `category` is an enum from `categories.nix`, which also defines sidebar order. Isolated module tests import `options.nix` alongside the modules under test.
