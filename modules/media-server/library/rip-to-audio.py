#!/usr/bin/env python3

import argparse
import asyncio
import collections
import os
import re
import sys
from pathlib import Path

from plexapi.server import PlexServer

REGEX_PATTERN = re.compile(r"\s*HDTV.*", re.IGNORECASE)
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


async def run_ffmpeg(
    infile: Path,
    outfile: Path,
    transcode: bool,
    track: str = None,
    album: str = None,
    artist: str = None,
) -> None:
    partial_file = outfile.parent / f"{outfile.stem}.partial{outfile.suffix}"
    copy_cmd = ["ffmpeg", "-y", "-nostdin", "-i", str(infile), "-vn"]
    if transcode:
        copy_cmd += ["-c:a", "aac", "-q:a", "2"]
    else:
        copy_cmd += ["-c:a", "copy"]

    if track:
        copy_cmd += ["-metadata", f"title={track}"]
    if album:
        copy_cmd += ["-metadata", f"album={album}"]
    if artist:
        copy_cmd += [
            "-metadata",
            f"artist={artist}",
            "-metadata",
            f"album_artist={artist}",
        ]

    copy_cmd += [str(partial_file)]
    process = await asyncio.create_subprocess_exec(
        *copy_cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
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
                print(
                    f"[WARN] Failed to copy audio, transcoding instead {outfile}:\n{err}",
                    file=sys.stderr,
                )
                await run_ffmpeg(
                    infile, outfile, transcode=True, album=album, artist=artist
                )
        except FFmpegError as err:
            print(f"[ERROR] Failed to process {outfile}:\n{err}", file=sys.stderr)
        else:
            print(f"[SUCCESS] Processed {outfile}", file=sys.stderr)
            return artist, album


async def merge_albums(plex: PlexServer, dst_dir: Path, albums_by_artist: dict):
    audiobooks = plex.library.section("Audiobooks")
    audiobooks.update()

    def is_scanning():
        return any(
            activity.title.startswith("Scanning") for activity in plex.activities
        )

    while is_scanning():
        print("Waiting for scan to complete...")
        await asyncio.sleep(5)

    for artist, albums in albums_by_artist.items():
        for album in albums:
            duplicate_albums = audiobooks.get(artist).albums(title=album)
            if len(duplicate_albums) > 1:
                duplicate_keys = [album.ratingKey for album in duplicate_albums[1:]]
                duplicate_albums[0].merge(duplicate_keys)


async def main():
    parser = argparse.ArgumentParser(
        description="Keep only audio in an MP4 container, preserving directory structure."
    )
    parser.add_argument("src_dir", type=Path, help="Source directory")
    parser.add_argument("dst_dir", type=Path, help="Destination directory")
    parser.add_argument("plex_token", type=str, help="Plex auth token")
    parser.add_argument(
        "--max-procs", type=int, default=4, help="Maximum ffmpeg processes"
    )
    args = parser.parse_args()

    src_dir = args.src_dir.resolve()
    dst_dir = args.dst_dir.resolve()
    plex = PlexServer("http://localhost:32400", args.plex_token)
    dst_dir.mkdir(parents=True, exist_ok=True)

    semaphore = asyncio.Semaphore(args.max_procs)
    tasks = []
    for root, _dirs, files in os.walk(src_dir):
        root_path = Path(root)
        for file_name in files:
            infile = root_path / file_name
            if infile.suffix.lower() in VIDEO_EXTENSIONS:
                rel_path = infile.relative_to(src_dir)
                cleaned_stem = REGEX_PATTERN.sub("", infile.stem).strip()
                outfile = dst_dir / rel_path.parent / (cleaned_stem + ".m4a")
                tasks.append(process_audio(infile, outfile, semaphore))

    results = await asyncio.gather(*tasks)
    albums_by_artist = collections.defaultdict(set)
    for artist, album in (result for result in results if result):
        albums_by_artist[artist].add(album)

    await merge_albums(plex, dst_dir, albums_by_artist)


if __name__ == "__main__":
    asyncio.run(main())
