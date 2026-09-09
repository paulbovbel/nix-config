#!/usr/bin/env python3

import json
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("container.nix")
REPOSITORIES = {
    "github.com/greenpau/caddy-security": "greenpau/caddy-security",
    "github.com/caddy-dns/route53": "caddy-dns/route53",
}


def latest_tag(repository: str) -> str:
    request = urllib.request.Request(
        f"https://api.github.com/repos/{repository}/releases/latest",
        headers={"Accept": "application/vnd.github+json", "User-Agent": "nix-config"},
    )
    if token := os.environ.get("GITHUB_TOKEN"):
        request.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)["tag_name"]


def caddy_expression(root: Path, plugins: list[str], hash_value: str) -> str:
    plugin_list = " ".join(json.dumps(plugin) for plugin in plugins)
    return f"""
      let
        flake = builtins.getFlake {json.dumps(str(root))};
        pkgs = flake.nixosConfigurations.media.pkgs;
      in
        pkgs.caddy.withPlugins {{
          plugins = [ {plugin_list} ];
          hash = {hash_value};
        }}
    """


def build_caddy(
    root: Path, plugins: list[str], hash_value: str
) -> subprocess.CompletedProcess:
    command = [
        "nix",
        "build",
        "--impure",
        "--no-link",
        "--expr",
        caddy_expression(root, plugins, hash_value),
    ]
    return subprocess.run(
        command, cwd=root, text=True, capture_output=True, check=False
    )


def main() -> int:
    root = MODULE_PATH.parents[2]
    source = MODULE_PATH.read_text()
    plugins = [
        f"{module}@{latest_tag(repository)}"
        for module, repository in REPOSITORIES.items()
    ]

    current_plugins = re.findall(r'"(github\.com/[^"@]+/[^"@]+@v[^\"]+)"', source)
    hash_pattern = (
        r'(caddyPackage = pkgs\.caddy\.withPlugins \{.*?hash = )"(sha256-[^"]+)";'
    )
    hash_match = re.search(hash_pattern, source, flags=re.DOTALL)
    if len(current_plugins) != len(plugins) or hash_match is None:
        print(
            "Unexpected Caddy module format; no changes were written.", file=sys.stderr
        )
        return 1

    if current_plugins == plugins:
        current_hash = hash_match.group(2)
        prefetch = build_caddy(root, plugins, json.dumps(current_hash))
        if prefetch.returncode == 0:
            print("Caddy plugins and dependency hash are already up to date.")
            return 0
        print("Updating Caddy plugin dependency hash.")
    else:
        print("Updating Caddy plugins:")
        for current, latest in zip(current_plugins, plugins, strict=True):
            print(f"  {current} -> {latest}")
        prefetch = build_caddy(root, plugins, "pkgs.lib.fakeHash")

    output = prefetch.stdout + prefetch.stderr
    match = re.search(r"got:\s+(sha256-[A-Za-z0-9+/=]+)", output)
    if not match:
        print(output, file=sys.stderr)
        print("Could not determine the Caddy plugin hash.", file=sys.stderr)
        return 1
    plugin_hash = match.group(1)

    updated = source
    for current, latest in zip(current_plugins, plugins, strict=True):
        updated = updated.replace(current, latest, 1)
    updated, replacements = re.subn(
        hash_pattern,
        rf'\1"{plugin_hash}";',
        updated,
        count=1,
        flags=re.DOTALL,
    )
    if replacements != 1:
        print(
            "Unexpected Caddy module format; no changes were written.", file=sys.stderr
        )
        return 1

    build = build_caddy(root, plugins, json.dumps(plugin_hash))
    if build.returncode != 0:
        print(build.stdout + build.stderr, file=sys.stderr)
        return build.returncode

    MODULE_PATH.write_text(updated)
    print(f"Updated Caddy plugins with dependency hash {plugin_hash}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
