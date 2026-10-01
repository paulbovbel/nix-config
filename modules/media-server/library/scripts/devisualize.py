#!/usr/bin/env python3
"""Convert Plex collection videos into audio-only files.

For each configured mapping, the script reads items from an input Plex library
collection and writes `.m4a` files into podcast folders for Audiobookshelf. Plex
reports media paths from inside the Plex container, so CLI root mappings translate
those paths back to host paths for ffmpeg.
"""

import argparse
import asyncio
import dataclasses
import json
import logging
import os
import re
import tempfile
import uuid
from pathlib import Path
from urllib.parse import urlsplit

import requests
from plexapi.exceptions import NotFound
from plexapi.server import PlexServer

FFMPEG_CONCURRENCY = 1
MANIFEST_FILENAME = ".devisualize-manifest.json"
PROCESSING_VERSION = 4
PATH_SEPARATOR_PATTERN = re.compile(r"[\\/]+")
LOGGER = logging.getLogger(__name__)


# Configuration


@dataclasses.dataclass(frozen=True)
class DevisualizeConfig:
    input_library: str
    collection: str


CONFIG = [
    DevisualizeConfig("Movies", "Devisualize"),
    DevisualizeConfig("TV Shows", "Devisualize"),
]


@dataclasses.dataclass(frozen=True)
class RuntimeConfig:
    host_media_root: Path
    plex_media_root: Path
    output_root: Path
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
    release_date: str | None = None
    season_number: int | None = None
    description: str | None = None


@dataclasses.dataclass(frozen=True)
class Conversion:
    infile: Path
    outfile: Path
    output_root: Path
    source_id: str
    item: object
    metadata: AudioMetadata


class FFmpegError(Exception):
    pass


class ProcessingManifest:
    def __init__(self, conversions: list[Conversion]):
        self.entries: dict[Path, dict] = {}
        for conversion in conversions:
            path = self._path(conversion)
            if path in self.entries:
                continue

            try:
                data = json.loads(path.read_text()) if path.exists() else {}
                items = data.get("items", {})
                if not isinstance(items, dict) or not all(
                    isinstance(key, str) and isinstance(value, dict)
                    for key, value in items.items()
                ):
                    raise ValueError("manifest items must be an object")
                self.entries[path] = items
            except (OSError, ValueError) as err:
                LOGGER.warning("Ignoring invalid manifest %s: %s", path, err)
                self.entries[path] = {}

    @staticmethod
    def _path(conversion: Conversion) -> Path:
        return conversion.output_root / MANIFEST_FILENAME

    @staticmethod
    def _state(conversion: Conversion) -> dict | None:
        try:
            source = conversion.infile.stat()
        except OSError as err:
            LOGGER.warning("Cannot inspect source file %s: %s", conversion.infile, err)
            return None

        return {
            "processing_version": PROCESSING_VERSION,
            "source": {
                "path": str(conversion.infile),
                "size": source.st_size,
                "mtime_ns": source.st_mtime_ns,
            },
            "output": str(conversion.outfile),
            "metadata": dataclasses.asdict(conversion.metadata),
            "artwork": getattr(conversion.item, "thumb", None)
            or getattr(conversion.item, "grandparentThumb", None),
        }

    def needs_processing(self, conversion: Conversion) -> bool:
        if not conversion.outfile.exists():
            return True

        state = self._state(conversion)
        if state is None:
            return True

        return self.entries[self._path(conversion)].get(conversion.source_id) != state

    def mark_processed(self, conversion: Conversion) -> None:
        state = self._state(conversion)
        if state is None:
            return

        path = self._path(conversion)
        previous = self.entries[path].get(conversion.source_id, {})
        previous_output = previous.get("output")
        self.entries[path][conversion.source_id] = state

        if previous_output and previous_output != str(conversion.outfile):
            stale_output = Path(previous_output)
            if stale_output.resolve().is_relative_to(conversion.output_root.resolve()):
                try:
                    stale_output.unlink(missing_ok=True)
                except OSError as err:
                    LOGGER.warning(
                        "Failed to remove stale output %s: %s", stale_output, err
                    )
            else:
                LOGGER.warning(
                    "Refusing to remove output outside library: %s", stale_output
                )

        partial_path = path.with_name(f"{path.name}.{uuid.uuid4().hex}.partial")
        try:
            partial_path.write_text(
                json.dumps({"items": self.entries[path]}, indent=2, sort_keys=True)
                + "\n"
            )
            os.replace(partial_path, path)
        finally:
            if partial_path.exists():
                partial_path.unlink()


# Audio Processing Helpers


async def write_audio(
    conversion: Conversion,
    artwork: Path | None = None,
    transcode: bool = False,
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

    cmd += ["-map", "0:a:0", "-map_metadata", "-1"]
    if artwork:
        cmd += ["-map", "1:v:0"]

    if transcode:
        cmd += ["-c:a", "aac", "-q:a", "2"]
    else:
        cmd += ["-c:a", "copy"]
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
    if metadata.release_date is not None:
        cmd += ["-metadata", f"date={metadata.release_date}"]
    # Audiobookshelf maps disc/track to podcast season/episode identifiers.
    if metadata.season_number is not None:
        cmd += ["-metadata", f"disc={metadata.season_number}"]
    if metadata.description:
        cmd += ["-metadata", f"comment={metadata.description}"]

    cmd += [str(partial_file)]
    process = None
    completed = False
    try:
        process = await asyncio.create_subprocess_exec(
            *cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
        )
        _, stderr = await process.communicate()

        if process.returncode != 0:
            raise FFmpegError(stderr.decode("utf-8", errors="replace"))

        os.replace(partial_file, outfile)
        completed = True
    finally:
        if not completed and partial_file.exists():
            partial_file.unlink()

        if process is not None and process.returncode is None:
            process.terminate()
            try:
                await asyncio.wait_for(process.wait(), timeout=5)
            except asyncio.TimeoutError:
                process.kill()
                await process.wait()


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


def movie_metadata(
    title: str, release_date: str | None = None, comedian: str | None = None
) -> AudioMetadata:
    title = title.strip()
    artist = comedian or title
    track = title
    separators = [
        (index, separator)
        for separator in (":", " - ")
        if (index := title.find(separator)) > 0
    ]
    if separators:
        separator_index, separator = min(separators)
        title_artist = title[:separator_index].strip()
        title_track = title[separator_index + len(separator) :].strip()
        if title_artist and title_track:
            artist, track = title_artist, title_track

    album = track
    if release_date:
        album = f"{album} ({release_date[:4]})"
    return AudioMetadata(artist, album, track, release_date=release_date)


def episode_metadata(item) -> AudioMetadata:
    artist = getattr(item, "grandparentTitle", None) or item.title
    season_number = getattr(item, "parentIndex", None)
    season = getattr(item, "parentTitle", None) or (
        f"Season {season_number}" if season_number is not None else "Unknown Season"
    )
    album = season.strip()
    episode_number = getattr(item, "index", None)
    if episode_number is None:
        track = item.title
    else:
        track = f"Episode {episode_number} - {item.title}"

    return AudioMetadata(
        artist.strip(),
        album.strip(),
        track.strip(),
        track_number=episode_number,
        season_number=season_number,
    )


def item_release_date(item) -> str | None:
    release_date = getattr(item, "originallyAvailableAt", None)
    if release_date is not None:
        value = (
            release_date.isoformat()
            if hasattr(release_date, "isoformat")
            else str(release_date)
        )
        return value.split("T", 1)[0].split(" ", 1)[0]

    year = getattr(item, "year", None)
    return str(year) if year is not None else None


def item_metadata(item) -> AudioMetadata:
    item_type = getattr(item, "TYPE", None)
    release_date = item_release_date(item)
    if item_type == "movie":
        roles = getattr(item, "roles", [])
        comedian = getattr(roles[0], "tag", None) if roles else None
        metadata = movie_metadata(item.title, release_date, comedian)
    elif item_type == "episode":
        metadata = episode_metadata(item)
    else:
        raise ValueError(
            f"Unsupported playable Plex item type {item_type}: {item.title}"
        )

    return dataclasses.replace(
        metadata,
        release_date=release_date,
        description=item_description(item),
    )


def item_description(item) -> str | None:
    summary = getattr(item, "summary", None)
    if not summary:
        return None

    def remove_plex_link(match):
        url = urlsplit(match.group())
        host = (url.hostname or "").casefold()
        if (
            url.scheme == "plex"
            or host == "plex.tv"
            or host.endswith(".plex.tv")
            or "/library/metadata/" in url.path
        ):
            return ""
        return match.group()

    return (
        re.sub(r"(?:https?://|plex://)[^\s<>\"']+", remove_plex_link, summary).strip()
        or None
    )


def path_segment(value: str) -> str:
    cleaned = PATH_SEPARATOR_PATTERN.sub("_", value).strip()
    cleaned = "".join(
        "_" if ord(character) < 32 else character for character in cleaned
    )
    if cleaned in {"", ".", ".."}:
        return "Unknown"

    return cleaned.encode("utf-8")[:200].decode("utf-8", errors="ignore") or "Unknown"


def output_path(
    output_root: Path,
    metadata: AudioMetadata,
) -> Path:
    title = metadata.track
    if metadata.release_date:
        title = f"{metadata.release_date} - {title}"
    # Keep folders unique across artists/shows without repeating the author in
    # Audiobookshelf's displayed podcast title (the album tag).
    podcast = f"{metadata.artist} - {metadata.album}"
    return output_root / path_segment(podcast) / f"{path_segment(title)}.m4a"


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


def podcast_artwork_url(conversion: Conversion) -> str | None:
    item = conversion.item
    if getattr(item, "TYPE", None) == "movie":
        thumb = getattr(item, "thumb", None)
    else:
        # Prefer season artwork; episode thumbnails are not podcast covers.
        thumb = getattr(item, "parentThumb", None) or getattr(
            item, "grandparentThumb", None
        )
    return item._server.url(thumb, includeToken=True) if thumb else None


def ensure_podcast_covers(conversions: list[Conversion]) -> None:
    covered = set()
    for conversion in conversions:
        cover = conversion.outfile.parent / "cover.jpg"
        if cover in covered:
            continue
        if cover.exists():
            covered.add(cover)
            continue

        partial = cover.with_name(f".{cover.name}.{uuid.uuid4().hex}.partial")
        try:
            url = podcast_artwork_url(conversion)
            if not url:
                continue
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            cover.parent.mkdir(parents=True, exist_ok=True)
            partial.write_bytes(response.content)
            os.replace(partial, cover)
            covered.add(cover)
            LOGGER.info("Saved podcast cover %s", cover)
        except (requests.RequestException, OSError) as err:
            LOGGER.warning(
                "Failed to save podcast cover %s (%s)", cover, type(err).__name__
            )
        finally:
            partial.unlink(missing_ok=True)


# Components


async def artwork_for(conversion: Conversion, artwork_dir: Path) -> Path | None:
    try:
        return await asyncio.to_thread(download_artwork, conversion.item, artwork_dir)
    except requests.RequestException as err:
        LOGGER.warning(
            "Failed to download artwork for %s (%s)",
            conversion.item.title,
            type(err).__name__,
        )
        return None


async def process_conversion(
    conversion: Conversion,
    artwork_dir: Path,
) -> Conversion | None:
    conversion.outfile.parent.mkdir(parents=True, exist_ok=True)

    try:
        artwork = await artwork_for(conversion, artwork_dir)
        LOGGER.info("Extracting %s -> %s", conversion.infile, conversion.outfile)
        try:
            await write_audio(conversion, artwork=artwork)
        except FFmpegError:
            LOGGER.info("Direct extraction failed; transcoding %s", conversion.infile)
            await write_audio(conversion, artwork=artwork, transcode=True)
    except (FFmpegError, OSError) as err:
        LOGGER.error("Failed to process %s:\n%s", conversion.outfile, err)
        return None

    LOGGER.info("Processed %s", conversion.outfile)
    return conversion


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
        outfile = output_path(output_root, metadata)
        conversions.append(
            Conversion(
                infile=infile,
                outfile=outfile,
                output_root=output_root,
                source_id=f"{item.ratingKey}:{index}",
                item=item,
                metadata=metadata,
            )
        )

    return conversions


def conversions_for_config(
    plex: PlexServer,
    mapper: PlexPathMapper,
    config: DevisualizeConfig,
    output_root: Path,
) -> list[Conversion]:
    plex_collection = collection(plex, config)
    if not plex_collection:
        return []

    conversions = []
    for collection_item in plex_collection.items():
        for item in playable_items(collection_item):
            conversions.extend(conversions_for_item(item, mapper, output_root))
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
        conversions.extend(
            conversions_for_config(plex, mapper, config, runtime_config.output_root)
        )
    return conversions


# Pipeline Orchestration


def dedupe_conversions(conversions: list[Conversion]) -> list[Conversion]:
    deduped = []
    seen = set()
    for conversion in conversions:
        outfile = conversion.outfile
        if outfile in seen:
            raise ValueError(
                f"Multiple Plex items map to the same output path: {outfile}"
            )

        seen.add(outfile)
        deduped.append(conversion)

    return deduped


def pending_conversions(
    conversions: list[Conversion], manifest: ProcessingManifest
) -> list[Conversion]:
    return [
        conversion
        for conversion in dedupe_conversions(conversions)
        if manifest.needs_processing(conversion)
    ]


def log_dry_run(conversions: list[Conversion], manifest: ProcessingManifest) -> None:
    conversions = pending_conversions(conversions, manifest)
    LOGGER.info("Dry run: %d conversion(s) would be processed", len(conversions))
    for conversion in conversions:
        LOGGER.info("Would convert %s -> %s", conversion.infile, conversion.outfile)


async def process_conversions(
    conversions: list[Conversion],
    manifest: ProcessingManifest,
    artwork_dir: Path,
):
    semaphore = asyncio.Semaphore(FFMPEG_CONCURRENCY)
    conversions = pending_conversions(conversions, manifest)

    async def process_one(conversion: Conversion):
        async with semaphore:
            processed = await process_conversion(conversion, artwork_dir)
        if processed:
            manifest.mark_processed(processed)

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
        "--output-root",
        type=Path,
        required=True,
        help="Audiobookshelf podcast directory",
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
        help="Log planned conversions without writing files",
    )
    args = parser.parse_args()
    plex_token = os.environ.get("PLEX_TOKEN")
    if not plex_token:
        parser.error("PLEX_TOKEN must be set")

    runtime_config = RuntimeConfig(
        host_media_root=args.host_media_root,
        plex_media_root=args.plex_media_root,
        output_root=args.output_root,
        plex_url=args.plex_url,
        dry_run=args.dry_run,
    )
    plex = PlexServer(runtime_config.plex_url, plex_token)
    conversions = collect_conversions(plex, runtime_config, CONFIG)
    manifest = ProcessingManifest(conversions)
    if runtime_config.dry_run:
        log_dry_run(conversions, manifest)
        return

    # Check all podcast folders, including ones whose audio is already up to date.
    await asyncio.to_thread(ensure_podcast_covers, conversions)
    with tempfile.TemporaryDirectory() as temporary_directory:
        artwork_dir = Path(temporary_directory)
        await process_conversions(conversions, manifest, artwork_dir)


if __name__ == "__main__":
    asyncio.run(main())
