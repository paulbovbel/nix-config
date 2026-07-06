#!/usr/bin/env python3
"""Convert Plex collection videos into audio-only files.

For each configured mapping, the script reads items from an input Plex library
collection and writes `.m4a` files under the output Plex library location. Plex
reports media paths from inside the Plex container, so CLI root mappings translate
those paths back to host paths for ffmpeg.
"""

import argparse
import asyncio
import collections
import dataclasses
import json
import logging
import os
import re
import tempfile
import uuid
from pathlib import Path

import requests
from plexapi.exceptions import NotFound
from plexapi.server import PlexServer

FFMPEG_CONCURRENCY = 1
PATH_SEPARATOR_PATTERN = re.compile(r"[\\/]+")
LOGGER = logging.getLogger(__name__)


# Configuration


@dataclasses.dataclass(frozen=True)
class DevisualizeConfig:
    input_library: str
    collection: str
    output_library: str


CONFIG = [
    DevisualizeConfig("Movies", "Devisualize", "Devisualized"),
    DevisualizeConfig("TV Shows", "Devisualize", "Devisualized"),
]


@dataclasses.dataclass(frozen=True)
class RuntimeConfig:
    host_media_root: Path
    plex_media_root: Path
    scan_timeout: int
    plex_url: str
    dry_run: bool


# Data Model


@dataclasses.dataclass(frozen=True)
class PlexPathMapper:
    """Map Plex container paths to host filesystem paths."""

    plex_media_root: Path
    host_media_root: Path

    def to_host(self, path: str) -> Path:
        plex_path = Path(path)
        try:
            return self.host_media_root / plex_path.relative_to(self.plex_media_root)
        except ValueError:
            return plex_path


@dataclasses.dataclass(frozen=True)
class AudioMetadata:
    artist: str
    album: str
    track: str
    track_number: int | None = None


@dataclasses.dataclass(frozen=True)
class Conversion:
    infile: Path
    outfile: Path
    item: object
    output_library: str
    metadata: AudioMetadata


class FFmpegError(Exception):
    pass


# Audio Processing Helpers


def loudnorm_filter(measured: dict | None = None) -> str:
    options = {
        "I": "-16",
        "TP": "-1.5",
        "LRA": "11",
    }
    if measured:
        options |= {
            "measured_I": measured["input_i"],
            "measured_TP": measured["input_tp"],
            "measured_LRA": measured["input_lra"],
            "measured_thresh": measured["input_thresh"],
            "offset": measured["target_offset"],
            "linear": "true",
            "print_format": "summary",
        }
    else:
        options["print_format"] = "json"

    return "loudnorm=" + ":".join(f"{key}={value}" for key, value in options.items())


def parse_loudnorm(stderr: str) -> dict:
    # ffmpeg prints loudnorm JSON to stderr mixed with other log lines.
    start = stderr.rfind("{")
    end = stderr.rfind("}")
    if start < 0 or end < start:
        raise FFmpegError(f"Failed to parse loudnorm measurements:\n{stderr}")

    try:
        return json.loads(stderr[start : end + 1])
    except json.JSONDecodeError as err:
        raise FFmpegError(f"Failed to parse loudnorm measurements:\n{stderr}") from err


async def _measure_loudness(infile: Path) -> dict:
    process = await asyncio.create_subprocess_exec(
        "ffmpeg",
        "-hide_banner",
        "-nostdin",
        "-i",
        str(infile),
        "-map",
        "0:a:0",
        "-af",
        loudnorm_filter(),
        "-f",
        "null",
        "-",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    _, stderr = await process.communicate()
    stderr_text = stderr.decode("utf-8", errors="replace")

    if process.returncode != 0:
        raise FFmpegError(stderr_text)

    return parse_loudnorm(stderr_text)


async def write_normalized_audio(
    conversion: Conversion,
    measured: dict,
    artwork: Path | None = None,
) -> None:
    infile = conversion.infile
    outfile = conversion.outfile
    metadata = conversion.metadata
    # Write beside the target so replacement is atomic on the destination filesystem.
    partial_file = (
        outfile.parent / f"{outfile.stem}.{uuid.uuid4().hex}.partial{outfile.suffix}"
    )
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-nostdin",
        "-i",
        str(infile),
    ]
    if artwork:
        cmd += ["-i", str(artwork)]

    cmd += ["-map", "0:a:0"]
    if artwork:
        cmd += ["-map", "1:v:0"]

    cmd += ["-c:a", "aac", "-q:a", "2", "-af", loudnorm_filter(measured)]
    if artwork:
        cmd += ["-c:v", "mjpeg", "-disposition:v:0", "attached_pic"]

    cmd += [
        "-metadata",
        f"title={metadata.track}",
        "-metadata",
        f"album={metadata.album}",
        "-metadata",
        f"artist={metadata.artist}",
        "-metadata",
        f"album_artist={metadata.artist}",
    ]
    if metadata.track_number is not None:
        cmd += ["-metadata", f"track={metadata.track_number}"]

    cmd += [str(partial_file)]
    process = await asyncio.create_subprocess_exec(
        *cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
    )
    _, stderr = await process.communicate()

    if process.returncode != 0:
        if partial_file.exists():
            partial_file.unlink()
        raise FFmpegError(stderr.decode("utf-8", errors="replace"))

    partial_file.rename(outfile)


# Plex Item And Metadata Helpers


def item_files(item) -> list[str]:
    files = []
    for media in item.media:
        for part in media.parts:
            if part.file:
                files.append(part.file)
    return files


def playable_items(item) -> list:
    item_type = getattr(item, "TYPE", None)
    if item_type == "show":
        return item.episodes()
    if item_type == "season":
        return item.episodes()
    if hasattr(item, "media"):
        return [item]

    LOGGER.warning("Skipping unsupported Plex item type %s: %s", item_type, item.title)
    return []


def movie_metadata(title: str) -> AudioMetadata:
    separators = [
        (index, separator)
        for separator in (":", " - ")
        if (index := title.find(separator)) > 0
    ]
    if separators:
        separator_index, separator = min(separators)
        artist = title[:separator_index].strip()
        album = title[separator_index + len(separator) :].strip()
        if artist and album:
            return AudioMetadata(artist, album, album)

    title = title.strip()
    return AudioMetadata(title, title, title)


def episode_metadata(item) -> AudioMetadata:
    artist = getattr(item, "grandparentTitle", None) or item.title
    album = getattr(item, "parentTitle", None) or artist
    episode_number = getattr(item, "index", None)
    if episode_number is None:
        track = item.title
    else:
        track = f"Episode {episode_number} - {item.title}"

    return AudioMetadata(artist.strip(), album.strip(), track.strip(), episode_number)


def item_metadata(item) -> AudioMetadata:
    item_type = getattr(item, "TYPE", None)
    if item_type == "movie":
        return movie_metadata(item.title)
    if item_type == "episode":
        return episode_metadata(item)

    raise ValueError(f"Unsupported playable Plex item type {item_type}: {item.title}")


def path_segment(value: str) -> str:
    cleaned = PATH_SEPARATOR_PATTERN.sub("_", value).strip()
    return cleaned or "Unknown"


def output_path(
    output_root: Path,
    input_library: str,
    metadata: AudioMetadata,
) -> Path:
    return (
        output_root
        / input_library
        / path_segment(metadata.artist)
        / path_segment(metadata.album)
        / f"{path_segment(metadata.track)}.m4a"
    )


def item_artwork_url(item) -> str | None:
    thumb = getattr(item, "thumb", None) or getattr(item, "grandparentThumb", None)
    if not thumb:
        return None

    return item._server.url(thumb, includeToken=True)


def download_artwork(item, directory: Path) -> Path | None:
    url = item_artwork_url(item)
    if not url:
        return None

    response = requests.get(url, timeout=30)
    response.raise_for_status()
    artwork = directory / f"{item.ratingKey}.jpg"
    artwork.write_bytes(response.content)
    return artwork


# Components


async def artwork_for(conversion: Conversion, artwork_dir: Path) -> Path | None:
    try:
        return await asyncio.to_thread(download_artwork, conversion.item, artwork_dir)
    except requests.RequestException as err:
        LOGGER.warning(
            "Failed to download artwork for %s: %s", conversion.item.title, err
        )
        return None


async def process_conversion(
    conversion: Conversion,
    artwork_dir: Path,
) -> Conversion | None:
    if conversion.outfile.exists():
        return None

    conversion.outfile.parent.mkdir(parents=True, exist_ok=True)

    try:
        artwork = await artwork_for(conversion, artwork_dir)
        LOGGER.info("Measuring loudness: %s", conversion.infile)
        measured = await _measure_loudness(conversion.infile)
        LOGGER.info("Converting %s -> %s", conversion.infile, conversion.outfile)
        await write_normalized_audio(conversion, measured, artwork=artwork)
    except FFmpegError as err:
        LOGGER.error("Failed to process %s:\n%s", conversion.outfile, err)
        return None

    LOGGER.info("Processed %s", conversion.outfile)
    return conversion


async def wait_for_scan(plex: PlexServer, scan_timeout: int):
    def is_scanning():
        return any(
            activity.title.startswith("Scanning") for activity in plex.activities
        )

    elapsed = 0
    while is_scanning() and elapsed < scan_timeout:
        LOGGER.info("Waiting for scan to complete...")
        await asyncio.sleep(5)
        elapsed += 5

    return not is_scanning()


async def merge_albums(output_section, albums_by_artist: dict):
    for artist, albums in albums_by_artist.items():
        try:
            plex_artist = output_section.get(artist)
        except NotFound:
            LOGGER.warning("Plex artist not found, skipping merge: %s", artist)
            continue

        for album in albums:
            duplicate_albums = plex_artist.albums(title=album)
            if len(duplicate_albums) > 1:
                duplicate_keys = [album.ratingKey for album in duplicate_albums[1:]]
                duplicate_albums[0].merge(duplicate_keys)
                LOGGER.info(
                    "Merged %d duplicate Plex album(s) for %s - %s",
                    len(duplicate_keys),
                    artist,
                    album,
                )


@dataclasses.dataclass
class PlexLibraryUpdater:
    plex: PlexServer
    scan_timeout: int
    pending: collections.defaultdict = dataclasses.field(
        default_factory=lambda: collections.defaultdict(
            lambda: collections.defaultdict(set)
        )
    )
    done: bool = False

    def _add_processed(self, conversion: Conversion) -> None:
        self.pending[conversion.output_library][conversion.metadata.artist].add(
            conversion.metadata.album
        )

    async def _scan_pending(self, output_library: str) -> None:
        albums_by_artist = self.pending.pop(output_library, None)
        if not albums_by_artist:
            return

        output_section = self.plex.library.section(output_library)
        LOGGER.info("Scanning Plex library: %s", output_library)
        output_section.update()
        if await wait_for_scan(self.plex, self.scan_timeout):
            await merge_albums(output_section, albums_by_artist)
        else:
            LOGGER.warning("Plex scan did not complete before timeout")
            for artist, albums in albums_by_artist.items():
                self.pending[output_library][artist].update(albums)

    async def _drain_queue(self, queue: asyncio.Queue) -> None:
        while True:
            try:
                conversion = queue.get_nowait()
            except asyncio.QueueEmpty:
                return

            if conversion is None:
                self.done = True
                continue

            self._add_processed(conversion)

    async def run(self, queue: asyncio.Queue) -> None:
        while not self.done or self.pending:
            if not self.pending:
                conversion = await queue.get()
                if conversion is None:
                    self.done = True
                else:
                    self._add_processed(conversion)
                continue

            for output_library in list(self.pending):
                await self._scan_pending(output_library)
                await self._drain_queue(queue)

        await self._drain_queue(queue)


def output_locations(
    plex: PlexServer,
    mapper: PlexPathMapper,
    config: DevisualizeConfig,
) -> list[Path]:
    output_section = plex.library.section(config.output_library)
    return [mapper.to_host(location) for location in output_section.locations]


def collection(plex: PlexServer, config: DevisualizeConfig):
    input_section = plex.library.section(config.input_library)
    try:
        return input_section.collection(config.collection)
    except NotFound:
        LOGGER.warning(
            "Collection not found in %s, skipping: %s",
            config.input_library,
            config.collection,
        )
        return None


def conversions_for_item(
    item,
    mapper: PlexPathMapper,
    config: DevisualizeConfig,
    output_root: Path,
) -> list[Conversion]:
    files = item_files(item)
    if not files:
        LOGGER.warning("Skipping item with no media files: %s", item.title)
        return []

    conversions = []
    for index, plex_file in enumerate(files):
        infile = mapper.to_host(plex_file)
        metadata = item_metadata(item)
        if index:
            metadata = dataclasses.replace(
                metadata, track=f"{metadata.track}-{index + 1}"
            )
        outfile = output_path(output_root, config.input_library, metadata)
        conversions.append(
            Conversion(infile, outfile, item, config.output_library, metadata)
        )

    return conversions


def conversions_for_config(
    plex: PlexServer,
    mapper: PlexPathMapper,
    config: DevisualizeConfig,
) -> list[Conversion]:
    locations = output_locations(plex, mapper, config)
    if not locations:
        LOGGER.warning("Output library has no locations: %s", config.output_library)
        return []

    plex_collection = collection(plex, config)
    if not plex_collection:
        return []

    conversions = []
    for collection_item in plex_collection.items():
        for item in playable_items(collection_item):
            conversions.extend(conversions_for_item(item, mapper, config, locations[0]))
    return conversions


def collect_conversions(
    plex: PlexServer,
    runtime_config: RuntimeConfig,
    configs: list[DevisualizeConfig],
) -> list[Conversion]:
    mapper = PlexPathMapper(
        runtime_config.plex_media_root.resolve(),
        runtime_config.host_media_root.resolve(),
    )
    conversions = []
    for config in configs:
        conversions.extend(conversions_for_config(plex, mapper, config))
    return conversions


# Pipeline Orchestration


def dedupe_conversions(conversions: list[Conversion]) -> list[Conversion]:
    deduped = []
    seen = set()
    for conversion in conversions:
        outfile = conversion.outfile
        if outfile in seen:
            LOGGER.warning("Skipping duplicate output path: %s", outfile)
            continue

        seen.add(outfile)
        deduped.append(conversion)

    return deduped


def pending_conversions(conversions: list[Conversion]) -> list[Conversion]:
    return [
        conversion
        for conversion in dedupe_conversions(conversions)
        if not conversion.outfile.exists()
    ]


def log_dry_run(conversions: list[Conversion]) -> None:
    conversions = pending_conversions(conversions)
    LOGGER.info("Dry run: %d conversion(s) would be processed", len(conversions))
    for conversion in conversions:
        LOGGER.info("Would convert %s -> %s", conversion.infile, conversion.outfile)


async def process_conversions(
    conversions: list[Conversion],
    artwork_dir: Path,
    plex_updates: asyncio.Queue,
):
    semaphore = asyncio.Semaphore(FFMPEG_CONCURRENCY)
    conversions = pending_conversions(conversions)

    async def process_one(conversion: Conversion):
        async with semaphore:
            processed = await process_conversion(conversion, artwork_dir)
        if processed:
            await plex_updates.put(processed)

    await asyncio.gather(*(process_one(conversion) for conversion in conversions))


# CLI


async def main():
    logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")

    parser = argparse.ArgumentParser(
        description="Convert configured Plex collections to audio-only files."
    )
    parser.add_argument("--host-media-root", type=Path, required=True)
    parser.add_argument(
        "--plex-media-root", type=Path, default=Path("/mnt/storage/share")
    )
    parser.add_argument(
        "--scan-timeout", type=int, default=300, help="Maximum seconds to wait for Plex"
    )
    parser.add_argument(
        "--plex-url",
        type=str,
        default=os.environ.get("PLEX_URL", "http://localhost:32400"),
        help="Plex server URL",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Log planned conversions without writing files or updating Plex",
    )
    args = parser.parse_args()
    plex_token = os.environ.get("PLEX_TOKEN")
    if not plex_token:
        parser.error("PLEX_TOKEN must be set")

    runtime_config = RuntimeConfig(
        host_media_root=args.host_media_root,
        plex_media_root=args.plex_media_root,
        scan_timeout=args.scan_timeout,
        plex_url=args.plex_url,
        dry_run=args.dry_run,
    )
    plex = PlexServer(runtime_config.plex_url, plex_token)
    conversions = collect_conversions(plex, runtime_config, CONFIG)
    if runtime_config.dry_run:
        log_dry_run(conversions)
        return

    with tempfile.TemporaryDirectory() as temporary_directory:
        artwork_dir = Path(temporary_directory)
        plex_updates = asyncio.Queue()
        plex_updater = PlexLibraryUpdater(plex, runtime_config.scan_timeout)
        plex_update_task = asyncio.create_task(plex_updater.run(plex_updates))

        try:
            await process_conversions(conversions, artwork_dir, plex_updates)
        finally:
            await plex_updates.put(None)
            await plex_update_task


if __name__ == "__main__":
    asyncio.run(main())
