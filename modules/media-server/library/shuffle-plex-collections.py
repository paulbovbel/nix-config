#!/usr/bin/env python3

import argparse
import logging
import os
import random

from plexapi.exceptions import BadRequest
from plexapi.server import PlexServer

LOGGER = logging.getLogger(__name__)


def section_label(section):
    return f"{section.title} ({section.key})"


def selected_sections(plex, section_titles):
    if section_titles:
        return [plex.library.section(title) for title in section_titles]

    return [section for section in plex.library.sections() if section.type != "photo"]


def collections_for_section(section, collection_titles):
    collections = section.search(libtype="collection")
    return [
        collection
        for collection in collections
        if collection.title in collection_titles
    ]


def shuffle_collection(collection, rng, dry_run):
    if collection.smart:
        LOGGER.info("Skipping smart collection: %s", collection.title)
        return False

    items = collection.items()
    if len(items) < 2:
        LOGGER.info("Skipping collection with fewer than 2 items: %s", collection.title)
        return False

    shuffled_items = items[:]
    rng.shuffle(shuffled_items)
    if [item.ratingKey for item in shuffled_items] == [
        item.ratingKey for item in items
    ]:
        LOGGER.info("Shuffle left collection unchanged: %s", collection.title)
        return False

    LOGGER.info(
        "%s collection %s (%d items)",
        "Would shuffle" if dry_run else "Shuffling",
        collection.title,
        len(items),
    )

    if dry_run:
        for index, item in enumerate(shuffled_items, start=1):
            LOGGER.info("  %d. %s", index, item.title)
        return True

    collection.sortUpdate(sort="custom")
    previous_item = None
    for item in shuffled_items:
        collection.moveItem(item, after=previous_item)
        previous_item = item

    return True


def main():
    logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")

    parser = argparse.ArgumentParser(
        description="Shuffle item order for Plex collections."
    )
    parser.add_argument(
        "collections",
        nargs="*",
        default=["Watchlist"],
        help="Collection titles to shuffle. Defaults to Watchlist.",
    )
    parser.add_argument(
        "--section",
        action="append",
        default=[],
        help="Library section title to process. May be provided multiple times.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        help="Seed for repeatable shuffles.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show the shuffled order without changing Plex.",
    )
    parser.add_argument(
        "--plex-url",
        type=str,
        default=os.environ.get("PLEX_URL", "http://localhost:50505"),
        help="Plex server URL",
    )
    args = parser.parse_args()

    plex_token = os.environ.get("PLEX_TOKEN")
    if not plex_token:
        parser.error("PLEX_TOKEN must be set")

    rng = random.Random(args.seed)
    plex = PlexServer(args.plex_url, plex_token)
    collection_titles = set(args.collections or ["Watchlist"])
    matched_titles = set()
    shuffled_count = 0

    for section in selected_sections(plex, args.section):
        LOGGER.info("Processing section: %s", section_label(section))
        try:
            collections = collections_for_section(section, collection_titles)
        except BadRequest as err:
            LOGGER.warning("Skipping section %s: %s", section_label(section), err)
            continue

        for collection in collections:
            matched_titles.add(collection.title)
            if shuffle_collection(collection, rng, args.dry_run):
                shuffled_count += 1

    missing_titles = collection_titles - matched_titles
    if missing_titles:
        parser.error("Collection not found: " + ", ".join(sorted(missing_titles)))

    LOGGER.info("Shuffled %d collection(s)", shuffled_count)


if __name__ == "__main__":
    main()
