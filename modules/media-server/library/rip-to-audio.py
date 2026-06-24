#!/usr/bin/env python3

import argparse
import asyncio
import collections
import logging
import os
import re
from pathlib import Path

from plexapi.exceptions import NotFound
from plexapi.server import PlexServer

RELEASE_SUFFIX_PATTERN = re.compile(r"\s*(?:HDTV|WEBDL).*", re.IGNORECASE)
LOGGER = logging.getLogger(__name__)
VIDEO_EXTENSIONS = {
    ".mp4",
    ".m4v",
    ".mkv",
    ".mov",
    ".avi",
    ".wmv",
    ".flv",
    ".webm",
    ".ts",
    ".mpeg",
    ".mpg",
}


class FFmpegError(Exception):
    pass


class FFprobeError(Exception):
    pass


async def probe_audio_codec(infile: Path) -> str:
    cmd = [
        "ffprobe",
        "-hide_banner",
        "-loglevel",
        "error",
        "-select_streams",
        "a:0",
        "-show_entries",
        "stream=codec_name",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        str(infile),
    ]
    process = await asyncio.create_subprocess_exec(
        *cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
    )
    stdout, stderr = await process.communicate()

    if process.returncode != 0:
        raise FFprobeError(stderr.decode("utf-8", errors="replace"))

    codec = stdout.decode("utf-8", errors="replace").strip().splitlines()
    if not codec:
        raise FFprobeError("no audio stream found")

    return codec[0]


async def run_ffmpeg(
    infile: Path,
    outfile: Path,
    transcode: bool,
    track: str | None = None,
    album: str | None = None,
    artist: str | None = None,
) -> None:
    partial_file = outfile.parent / f"{outfile.stem}.partial{outfile.suffix}"
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-nostdin",
        "-i",
        str(infile),
        "-vn",
    ]
    if transcode:
        cmd += ["-c:a", "aac", "-q:a", "2"]
    else:
        cmd += ["-c:a", "copy"]

    if track:
        cmd += ["-metadata", f"title={track}"]
    if album:
        cmd += ["-metadata", f"album={album}"]
    if artist:
        cmd += [
            "-metadata",
            f"artist={artist}",
            "-metadata",
            f"album_artist={artist}",
        ]

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


async def process_audio(infile: Path, outfile: Path, semaphore: asyncio.Semaphore):
    async with semaphore:
        if outfile.exists():
            return

        outfile.parent.mkdir(parents=True, exist_ok=True)
        track = outfile.stem
        album = outfile.parent.name
        artist = outfile.parent.parent.name

        try:
            codec = None
            try:
                codec = await probe_audio_codec(infile)
            except FFprobeError as err:
                LOGGER.warning("Failed to probe audio codec for %s:\n%s", infile, err)

            if codec == "aac":
                try:
                    await run_ffmpeg(
                        infile,
                        outfile,
                        transcode=False,
                        track=track,
                        album=album,
                        artist=artist,
                    )
                except FFmpegError as err:
                    LOGGER.warning(
                        "Failed to copy AAC audio, transcoding instead %s:\n%s",
                        outfile,
                        err,
                    )
                    await run_ffmpeg(
                        infile,
                        outfile,
                        transcode=True,
                        track=track,
                        album=album,
                        artist=artist,
                    )
            else:
                if codec:
                    LOGGER.info("Transcoding %s audio for %s", codec, outfile)
                await run_ffmpeg(
                    infile,
                    outfile,
                    transcode=True,
                    track=track,
                    album=album,
                    artist=artist,
                )
        except FFmpegError as err:
            LOGGER.error("Failed to process %s:\n%s", outfile, err)
        else:
            LOGGER.info("Processed %s", outfile)
            return artist, album


async def merge_albums(
    plex: PlexServer, dst_dir: Path, albums_by_artist: dict, scan_timeout: int
):
    audiobooks = plex.library.section("Audiobooks")
    audiobooks.update()

    def is_scanning():
        return any(
            activity.title.startswith("Scanning") for activity in plex.activities
        )

    elapsed = 0
    while is_scanning() and elapsed < scan_timeout:
        LOGGER.info("Waiting for scan to complete...")
        await asyncio.sleep(5)
        elapsed += 5

    if is_scanning():
        LOGGER.warning("Plex scan did not complete before timeout")
        return

    for artist, albums in albums_by_artist.items():
        try:
            plex_artist = audiobooks.get(artist)
        except NotFound:
            LOGGER.warning("Plex artist not found, skipping merge: %s", artist)
            continue

        for album in albums:
            duplicate_albums = plex_artist.albums(title=album)
            if len(duplicate_albums) > 1:
                duplicate_keys = [album.ratingKey for album in duplicate_albums[1:]]
                duplicate_albums[0].merge(duplicate_keys)


async def main():
    logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")

    parser = argparse.ArgumentParser(
        description="Keep only audio in an MP4 container, preserving directory structure."
    )
    parser.add_argument("src_dir", type=Path, help="Source directory")
    parser.add_argument("dst_dir", type=Path, help="Destination directory")
    parser.add_argument(
        "--max-procs", type=int, default=4, help="Maximum ffmpeg processes"
    )
    parser.add_argument(
        "--scan-timeout", type=int, default=300, help="Maximum seconds to wait for Plex"
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

    src_dir = args.src_dir.resolve()
    dst_dir = args.dst_dir.resolve()
    plex = PlexServer(args.plex_url, plex_token)
    dst_dir.mkdir(parents=True, exist_ok=True)

    semaphore = asyncio.Semaphore(args.max_procs)
    tasks = []
    for root, _dirs, files in os.walk(src_dir):
        root_path = Path(root)
        for file_name in files:
            infile = root_path / file_name
            if infile.suffix.lower() in VIDEO_EXTENSIONS:
                rel_path = infile.relative_to(src_dir)
                cleaned_stem = RELEASE_SUFFIX_PATTERN.sub("", infile.stem).strip()
                outfile = dst_dir / rel_path.parent / (cleaned_stem + ".m4a")
                tasks.append(process_audio(infile, outfile, semaphore))

    results = await asyncio.gather(*tasks)
    albums_by_artist = collections.defaultdict(set)
    for artist, album in (result for result in results if result):
        albums_by_artist[artist].add(album)

    await merge_albums(plex, dst_dir, albums_by_artist, args.scan_timeout)


if __name__ == "__main__":
    asyncio.run(main())
