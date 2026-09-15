#!/usr/bin/env python3

import argparse
import re
import sys
from collections.abc import Iterable, Iterator

FENCE_PATTERN = re.compile(r"^\s*(`{3,}|~{3,})")
HEADING_PATTERN = re.compile(r"^(#{1,6})(\s+.*)$")


def transform_markdown(lines: Iterable[str], *, drop_title: bool) -> Iterator[str]:
    fence: tuple[str, int] | None = None
    title_dropped = False

    for line in lines:
        fence_match = FENCE_PATTERN.match(line)
        if fence_match:
            marker = fence_match.group(1)
            if fence is None:
                fence = (marker[0], len(marker))
            elif marker[0] == fence[0] and len(marker) >= fence[1]:
                fence = None
            yield line
            continue

        heading = HEADING_PATTERN.match(line) if fence is None else None
        if heading is None:
            yield line
            continue

        level = len(heading.group(1))
        if drop_title and not title_dropped and level == 1:
            title_dropped = True
            continue

        yield f"{'#' * min(level + 1, 6)}{heading.group(2)}\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("path")
    parser.add_argument("--drop-title", action="store_true")
    args = parser.parse_args()

    with open(args.path, encoding="utf-8") as source:
        sys.stdout.writelines(transform_markdown(source, drop_title=args.drop_title))


if __name__ == "__main__":
    main()
