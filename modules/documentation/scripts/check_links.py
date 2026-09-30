#!/usr/bin/env python3

import argparse
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


class DocumentParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.ids: set[str] = set()
        self.links: list[str] = []
        self.resources: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        if identifier := attributes.get("id"):
            self.ids.add(identifier)
        if tag == "a" and (href := attributes.get("href")):
            self.links.append(href)
        if tag == "link" and (href := attributes.get("href")):
            self.resources.append(href)
        if tag in {"img", "script"} and (source := attributes.get("src")):
            self.resources.append(source)


def parse_document(path: Path) -> DocumentParser:
    parser = DocumentParser()
    parser.feed(path.read_text(encoding="utf-8"))
    return parser


def check_site(site: Path) -> list[str]:
    documents = {path.resolve(): parse_document(path) for path in site.glob("*.html")}
    files = {path.resolve() for path in site.iterdir() if path.is_file()}
    failures: list[str] = []

    for source, document in documents.items():
        for href in document.links:
            target = urlsplit(href)
            if target.scheme or target.netloc:
                continue

            target_path = (
                source if not target.path else source.parent / unquote(target.path)
            )
            target_path = target_path.resolve()
            if target_path not in documents:
                failures.append(f"{source.name}: missing target {href}")
                continue
            if (
                target.fragment
                and unquote(target.fragment) not in documents[target_path].ids
            ):
                failures.append(f"{source.name}: missing anchor {href}")

        for reference in document.resources:
            target = urlsplit(reference)
            if target.scheme or target.netloc:
                continue
            target_path = (source.parent / unquote(target.path)).resolve()
            if target_path not in files:
                failures.append(f"{source.name}: missing target {reference}")

    return failures


def main() -> None:
    argument_parser = argparse.ArgumentParser()
    argument_parser.add_argument("site", type=Path)
    args = argument_parser.parse_args()

    failures = check_site(args.site)
    if failures:
        raise SystemExit("\n".join(failures))


if __name__ == "__main__":
    main()
