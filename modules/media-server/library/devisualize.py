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
from urllib.parse import quote

import requests
from plexapi.exceptions import NotFound
from plexapi.server import PlexServer

FFMPEG_CONCURRENCY = 1
MANIFEST_FILENAME = ".devisualize-manifest.json"
MINIMUM_PROGRESS_CHANGE_MS = 1000
PROCESSING_VERSION = 1
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
    release_date: str | None = None


@dataclasses.dataclass(frozen=True)
class Conversion:
    infile: Path
    outfile: Path
    output_root: Path
    source_id: str
    item: object
    output_library: str
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
            "plex_url": item_plex_url(conversion.item),
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
        "-metadata",
        f"comment={item_plex_url(conversion.item)}",
    ]
    if metadata.track_number is not None:
        cmd += ["-metadata", f"track={metadata.track_number}"]
    if metadata.release_date is not None:
        cmd += ["-metadata", f"date={metadata.release_date}"]

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
    if item_type == "movie":
        metadata = movie_metadata(item.title)
    elif item_type == "episode":
        metadata = episode_metadata(item)
    else:
        raise ValueError(
            f"Unsupported playable Plex item type {item_type}: {item.title}"
        )

    return dataclasses.replace(metadata, release_date=item_release_date(item))


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


def item_plex_url(item) -> str:
    machine_identifier = quote(str(item._server.machineIdentifier), safe="")
    metadata_key = quote(f"/library/metadata/{item.ratingKey}", safe="")
    return (
        "https://app.plex.tv/desktop/#!/server/"
        f"{machine_identifier}/details?key={metadata_key}"
    )


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


def progress_fraction(item) -> float:
    if bool(getattr(item, "isPlayed", False)):
        return 1.0

    duration = getattr(item, "duration", None) or 0
    if duration <= 0:
        return 0.0

    offset = getattr(item, "viewOffset", None) or 0
    return max(0.0, min(offset / duration, 1.0))


def progress_timestamp(item) -> float:
    last_viewed_at = getattr(item, "lastViewedAt", None)
    return last_viewed_at.timestamp() if last_viewed_at is not None else 0.0


def mirror_progress_attributes(source, target, offset: int) -> None:
    target.viewCount = 1 if bool(getattr(source, "isPlayed", False)) else 0
    target.viewOffset = offset
    target.lastViewedAt = getattr(source, "lastViewedAt", None)


def copy_progress(source, target) -> bool:
    source_progress = progress_fraction(source)
    target_progress = progress_fraction(target)
    target_duration = getattr(target, "duration", None) or 0
    source_played = bool(getattr(source, "isPlayed", False))
    target_played = bool(getattr(target, "isPlayed", False))

    if source_played:
        if target_played:
            return False
        target.markPlayed()
        mirror_progress_attributes(source, target, 0)
        return True

    changed = False
    if target_played:
        target.markUnplayed()
        mirror_progress_attributes(source, target, 0)
        changed = True

    if source_progress == 0.0:
        if target_progress > 0.0 and not changed:
            target.markUnplayed()
            mirror_progress_attributes(source, target, 0)
            changed = True
        return changed

    if target_duration <= 1:
        return changed

    desired_offset = max(
        1, min(int(source_progress * target_duration), target_duration - 1)
    )
    current_offset = getattr(target, "viewOffset", None) or 0
    if abs(desired_offset - current_offset) < MINIMUM_PROGRESS_CHANGE_MS:
        return changed

    target.updateProgress(desired_offset)
    mirror_progress_attributes(source, target, desired_offset)
    return True


def sync_progress_pair(first, second) -> bool:
    first_timestamp = progress_timestamp(first)
    second_timestamp = progress_timestamp(second)
    if first_timestamp > second_timestamp:
        return copy_progress(first, second)
    if second_timestamp > first_timestamp:
        return copy_progress(second, first)
    if progress_fraction(first) >= progress_fraction(second):
        return copy_progress(first, second)
    return copy_progress(second, first)


def sync_progress(
    plex: PlexServer,
    runtime_config: RuntimeConfig,
    conversions: list[Conversion],
) -> None:
    mapper = PlexPathMapper(
        runtime_config.plex_media_root.resolve(),
        runtime_config.host_media_root.resolve(),
    )
    output_tracks = {}
    for output_library in {conversion.output_library for conversion in conversions}:
        try:
            tracks = plex.library.section(output_library).search(libtype="track")
        except Exception as err:
            LOGGER.error(
                "Failed to list tracks in %s (%s)", output_library, type(err).__name__
            )
            continue

        for track in tracks:
            for plex_file in item_files(track):
                output_tracks[mapper.to_host(plex_file).resolve()] = track

    source_items = {}
    synced_pairs = set()
    for conversion in conversions:
        output_track = output_tracks.get(conversion.outfile.resolve())
        if output_track is None:
            LOGGER.warning("Output track not found in Plex: %s", conversion.outfile)
            continue

        source_key = str(conversion.item.ratingKey)
        pair = (source_key, str(output_track.ratingKey))
        if pair in synced_pairs:
            continue
        synced_pairs.add(pair)

        try:
            if source_key not in source_items:
                source_items[source_key] = conversion.item.reload()
            source_item = source_items[source_key]
            if sync_progress_pair(source_item, output_track):
                LOGGER.info(
                    "Synchronized progress between Plex items %s and %s",
                    source_key,
                    output_track.ratingKey,
                )
        except Exception as err:
            LOGGER.error(
                "Failed to synchronize progress for Plex item %s (%s)",
                source_key,
                type(err).__name__,
            )


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
            Conversion(
                infile=infile,
                outfile=outfile,
                output_root=output_root,
                source_id=f"{item.ratingKey}:{index}",
                item=item,
                output_library=config.output_library,
                metadata=metadata,
            )
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
    plex_updates: asyncio.Queue,
):
    semaphore = asyncio.Semaphore(FFMPEG_CONCURRENCY)
    conversions = pending_conversions(conversions, manifest)

    async def process_one(conversion: Conversion):
        async with semaphore:
            processed = await process_conversion(conversion, artwork_dir)
        if processed:
            manifest.mark_processed(processed)
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
    manifest = ProcessingManifest(conversions)
    if runtime_config.dry_run:
        log_dry_run(conversions, manifest)
        return

    with tempfile.TemporaryDirectory() as temporary_directory:
        artwork_dir = Path(temporary_directory)
        plex_updates = asyncio.Queue()
        plex_updater = PlexLibraryUpdater(plex, runtime_config.scan_timeout)
        plex_update_task = asyncio.create_task(plex_updater.run(plex_updates))

        try:
            await process_conversions(conversions, manifest, artwork_dir, plex_updates)
        finally:
            await plex_updates.put(None)
            await plex_update_task

    sync_progress(plex, runtime_config, conversions)


if __name__ == "__main__":
    asyncio.run(main())
