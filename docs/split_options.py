#!/usr/bin/env python3

import argparse
import json
from pathlib import Path


def split_options(options: dict, module_names: list[str]) -> dict[str, dict]:
    modules = {name: {} for name in module_names}
    for option_name, option in options.items():
        owners = set()
        for declaration in option.get("declarations", []):
            if not isinstance(declaration, dict):
                continue
            parts = declaration.get("name", "").split("/")
            if len(parts) >= 2 and parts[0] == "modules":
                owners.add(parts[1])
        for owner in owners & modules.keys():
            modules[owner][option_name] = option
    return modules


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("modules", nargs="+")
    args = parser.parse_args()

    options = json.loads(args.source.read_text(encoding="utf-8"))
    args.destination.mkdir(parents=True, exist_ok=True)
    for name, module_options in split_options(options, args.modules).items():
        output = args.destination / f"{name}.json"
        output.write_text(json.dumps(module_options), encoding="utf-8")


if __name__ == "__main__":
    main()
