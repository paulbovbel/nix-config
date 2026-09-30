#!/usr/bin/env python3

import argparse
import json
from html.parser import HTMLParser
from pathlib import Path


class HeadingParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.current: tuple[str, str] | None = None
        self.current_text: list[str] = []
        self.section = ""
        self.headings: list[tuple[str, str, str]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in {"h1", "h2", "h3"}:
            identifier = dict(attrs).get("id") or ""
            self.current = (tag, identifier)
            self.current_text = []

    def handle_data(self, data: str) -> None:
        if self.current:
            self.current_text.append(data)

    def handle_endtag(self, tag: str) -> None:
        if not self.current or tag != self.current[0]:
            return

        heading_tag, identifier = self.current
        label = " ".join("".join(self.current_text).split())
        if heading_tag == "h2":
            self.section = identifier
        elif label and (heading_tag == "h1" or self.section == "options"):
            self.headings.append((heading_tag, identifier, label))
        self.current = None
        self.current_text = []


def build_index(site: Path, module_names: list[str]) -> list[dict[str, str]]:
    entries = []
    for name in module_names:
        path = site / f"{name}.html"
        parser = HeadingParser()
        parser.feed(path.read_text(encoding="utf-8"))
        for tag, identifier, label in parser.headings:
            entries.append(
                {
                    "kind": "module" if tag == "h1" else "option",
                    "label": label,
                    "url": f"{name}.html" + (f"#{identifier}" if identifier else ""),
                }
            )
    return entries


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("site", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("modules", nargs="+")
    args = parser.parse_args()

    args.output.write_text(
        json.dumps(build_index(args.site, args.modules), separators=(",", ":")),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
