#!/usr/bin/env python3
import asyncio
import json
import logging
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from xml.etree import ElementTree

import aiohttp
from PIL import Image


YOUTUBE_API = "https://www.googleapis.com/youtube/v3"
BGUTIL_PROVIDER = "http://127.0.0.1:4416"
DURATION_RE = re.compile(r"^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$")
POSTER_SIZE = (1000, 1500)
POSTER_AVATAR_SIZE = (780, 780)
MIN_VIDEO_SECONDS = 180
LOGGER = logging.getLogger("download-popular-videos")
TRANSIENT_YT_DLP_ERRORS = ("HTTP Error 429", "Too Many Requests")


class CommandError(RuntimeError):
    def __init__(self, args: tuple[str, ...], returncode: int, stderr: str):
        super().__init__(
            f"command failed with exit code {returncode}: {' '.join(args)}"
        )
        self.stderr = stderr


def is_transient_youtube_error(error: BaseException) -> bool:
    return any(pattern in str(error) for pattern in TRANSIENT_YT_DLP_ERRORS)


@dataclass(frozen=True)
class ChannelMetadata:
    id: str
    name: str
    safe_name: str
    dir: Path
    poster_url: str


def usage() -> None:
    print(f"usage: {sys.argv[0]} CHANNELS_JSON OUTPUT_DIR", file=sys.stderr)


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9. _-]", "_", name).strip()


def duration_seconds(duration: str) -> int | None:
    match = DURATION_RE.match(duration)
    if match is None:
        return None

    hours, minutes, seconds = (int(part or 0) for part in match.groups())
    return hours * 3600 + minutes * 60 + seconds


async def run_command(*args: str, capture_stdout: bool = False) -> str:
    LOGGER.info("running: %s", " ".join(args))
    proc = await asyncio.create_subprocess_exec(
        *args,
        stdout=asyncio.subprocess.PIPE if capture_stdout else None,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout_task = asyncio.create_task(read_stdout(proc.stdout))
    stderr_task = asyncio.create_task(log_stream(proc.stderr))
    returncode = await proc.wait()
    stdout, stderr = await asyncio.gather(stdout_task, stderr_task)
    if returncode != 0:
        raise CommandError(args, returncode, stderr)
    return stdout


async def read_stdout(stream: asyncio.StreamReader | None) -> str:
    if stream is None:
        return ""
    return (await stream.read()).decode(errors="replace")


async def log_stream(stream: asyncio.StreamReader | None) -> str:
    if stream is None:
        return ""
    lines = []
    while line := await stream.readline():
        text = line.decode(errors="replace").rstrip()
        lines.append(text)
        LOGGER.info("yt-dlp: %s", text)
    return "\n".join(lines)


def add_element(parent: ElementTree.Element, name: str, value: object) -> None:
    if value is None or value == "":
        return
    ElementTree.SubElement(parent, name).text = str(value)


def write_nfo(path: Path, root_name: str, elements: list[tuple[str, object]]) -> None:
    root = ElementTree.Element(root_name)
    for name, value in elements:
        add_element(root, name, value)
    ElementTree.indent(root, space="  ")
    tree = ElementTree.ElementTree(root)
    tree.write(path, encoding="utf-8", xml_declaration=True)
    path.write_text(path.read_text(encoding="utf-8") + "\n", encoding="utf-8")


def yyyymmdd_to_iso(value: str | None) -> str:
    if not value or len(value) != 8:
        return ""
    return f"{value[0:4]}-{value[4:6]}-{value[6:8]}"


def best_avatar_url(metadata: dict) -> str:
    thumbnails = metadata.get("thumbnails") or []
    if not thumbnails:
        return ""

    def thumbnail_score(item: dict) -> float:
        width = item.get("width") or 0
        height = item.get("height") or 0
        if width <= 0 or height <= 0:
            return 0
        aspect_penalty = abs((width / height) - 1)
        return (width * height) / (1 + aspect_penalty * 10)

    thumbnail = max(
        thumbnails,
        key=thumbnail_score,
    )
    return thumbnail.get("url") or ""


def write_show_nfo(
    channel_dir: Path, channel_name: str, channel_id: str, channel: str
) -> None:
    write_nfo(
        channel_dir / "tvshow.nfo",
        "tvshow",
        [
            ("title", channel_name),
            ("showtitle", channel_name),
            ("uniqueid", channel_id),
            ("studio", "YouTube"),
            ("id", channel_id),
            ("youtube_handle", channel),
            ("webpage", f"https://www.youtube.com/{channel}"),
        ],
    )


def write_episode_nfo(video_path: Path, metadata: dict, channel_name: str) -> None:
    upload_date = yyyymmdd_to_iso(metadata.get("upload_date"))
    release_timestamp = metadata.get("release_timestamp")
    timestamp = metadata.get("timestamp")
    year = metadata.get("release_year") or (upload_date[:4] if upload_date else "")
    write_nfo(
        video_path.with_suffix(".nfo"),
        "episodedetails",
        [
            ("title", metadata.get("title")),
            ("showtitle", channel_name),
            ("aired", upload_date),
            ("premiered", upload_date),
            ("year", year),
            ("runtime", round((metadata.get("duration") or 0) / 60) or ""),
            ("uniqueid", metadata.get("id")),
            ("id", metadata.get("id")),
            ("studio", metadata.get("channel") or metadata.get("uploader")),
            ("director", metadata.get("uploader")),
            ("credits", metadata.get("uploader")),
            ("webpage", metadata.get("webpage_url")),
            ("viewcount", metadata.get("view_count")),
            ("likecount", metadata.get("like_count")),
            ("timestamp", release_timestamp or timestamp),
            ("plot", metadata.get("description")),
        ],
    )


def last_absolute_path_from_stdout(stdout: str) -> Path | None:
    paths = [Path(line) for line in stdout.splitlines() if line.startswith("/")]
    return paths[-1] if paths else None


def render_poster(source_path: Path, poster_path: Path) -> None:
    with Image.open(source_path) as source:
        source = source.convert("RGB")
        background_color = source.resize((1, 1)).getpixel((0, 0))
        LOGGER.info(
            "rendering poster with background %s: %s", background_color, poster_path
        )

        poster = Image.new("RGB", POSTER_SIZE, background_color)
        avatar = source.copy()
        avatar.thumbnail(POSTER_AVATAR_SIZE, Image.Resampling.LANCZOS)
        x = (POSTER_SIZE[0] - avatar.width) // 2
        y = (POSTER_SIZE[1] - avatar.height) // 2
        poster.paste(avatar, (x, y))
        poster.save(poster_path, format="JPEG", quality=92)


async def wait_for_bgutil_provider(session: aiohttp.ClientSession) -> None:
    for attempt in range(1, 31):
        try:
            async with session.get(f"{BGUTIL_PROVIDER}/ping") as response:
                if response.ok:
                    LOGGER.info("bgutil provider is ready")
                    return
        except aiohttp.ClientError as error:
            LOGGER.info("bgutil provider not ready on attempt %d: %s", attempt, error)
        await asyncio.sleep(1)

    raise RuntimeError(f"bgutil provider is not reachable at {BGUTIL_PROVIDER}")


class PopularVideoDownloader:
    def __init__(self, session: aiohttp.ClientSession, output_dir: Path, api_key: str):
        self._session = session
        self._output_dir = output_dir
        self._archive_file = output_dir / ".popular-videos-archive.txt"
        self._api_key = api_key

    async def process_channel(self, channel_config: dict) -> None:
        channel = channel_config["channel"]
        LOGGER.info("processing channel: %s", channel)
        if not channel.startswith("@"):
            raise ValueError(
                f"channel must be a YouTube handle beginning with @: {channel}"
            )

        metadata = await self._channel_metadata(channel)
        if not metadata.id:
            LOGGER.warning("failed to resolve channel ID for %s", channel)
            return
        LOGGER.info("resolved %s to %s (%s)", channel, metadata.name, metadata.id)

        metadata.dir.mkdir(parents=True, exist_ok=True)
        await self._download_poster(metadata.poster_url, metadata.dir)
        write_show_nfo(metadata.dir, metadata.name, metadata.id, channel)

        urls = await self._popular_video_urls(
            channel,
            metadata.id,
            int(channel_config["count"]),
            channel_config.get("maxLength"),
        )
        for video_url in urls:
            await self._download_video_with_retries(
                video_url, metadata.dir, metadata.safe_name, metadata.name
            )
        LOGGER.info("finished channel: %s", channel)

    async def _youtube_get(self, path: str, params: dict[str, str]) -> dict:
        LOGGER.info("youtube api request: %s", path)
        async with self._session.get(
            f"{YOUTUBE_API}/{path}",
            params=params,
            headers={"X-goog-api-key": self._api_key},
        ) as response:
            response.raise_for_status()
            return await response.json()

    async def _channel_metadata(self, channel: str) -> ChannelMetadata:
        url = f"https://www.youtube.com/{channel}/videos"
        metadata = json.loads(
            await run_command(
                "python3",
                "-m",
                "yt_dlp",
                "--flat-playlist",
                "--dump-single-json",
                url,
                capture_stdout=True,
            )
        )
        entries = metadata.get("entries") or [{}]
        channel_id = metadata.get("channel_id") or entries[0].get("channel_id") or ""
        channel_name = (
            metadata.get("channel")
            or metadata.get("uploader")
            or metadata.get("playlist_uploader")
            or re.sub(r" - Videos$", "", metadata.get("title") or "")
            or channel.removeprefix("@")
        )
        channel_safe_name = safe_name(channel_name)
        return ChannelMetadata(
            channel_id,
            channel_name,
            channel_safe_name,
            self._output_dir / channel_safe_name,
            best_avatar_url(metadata),
        )

    async def _download_poster(self, poster_url: str, channel_dir: Path) -> None:
        poster_path = channel_dir / "poster.jpg"
        source_path = channel_dir / ".poster-source"
        if not poster_url or poster_path.exists():
            LOGGER.info("skipping poster for %s", channel_dir)
            return

        LOGGER.info("downloading poster source: %s", poster_url)
        async with self._session.get(poster_url) as response:
            response.raise_for_status()
            source_path.write_bytes(await response.read())

        try:
            await asyncio.to_thread(render_poster, source_path, poster_path)
        except OSError:
            LOGGER.warning("poster render failed, using source image: %s", poster_path)
            source_path.rename(poster_path)
        finally:
            source_path.unlink(missing_ok=True)
        LOGGER.info("wrote poster: %s", poster_path)

    async def _popular_video_urls(
        self,
        channel: str,
        channel_id: str,
        count: int,
        max_length: int | None,
    ) -> list[str]:
        accepted: list[str] = []
        page_token = ""
        max_seconds = max_length * 60 if max_length is not None else None
        LOGGER.info(
            "selecting top %d popular videos for %s with max length %s minutes",
            count,
            channel,
            max_length if max_length is not None else "unlimited",
        )

        while len(accepted) < count:
            params = {
                "part": "id",
                "type": "video",
                "order": "viewCount",
                "maxResults": "50",
                "channelId": channel_id,
            }
            if page_token:
                params["pageToken"] = page_token

            search = await self._youtube_get("search", params)
            ids = [item["id"]["videoId"] for item in search.get("items", [])]
            LOGGER.info("fetched %d candidate videos for %s", len(ids), channel)
            if not ids:
                break

            videos = await self._youtube_get(
                "videos",
                {"part": "contentDetails", "id": ",".join(ids)},
            )
            durations = {
                item["id"]: duration_seconds(item["contentDetails"]["duration"])
                for item in videos.get("items", [])
            }

            for video_id in ids:
                duration = durations.get(video_id)
                if duration is None:
                    continue
                if duration < MIN_VIDEO_SECONDS:
                    continue
                if max_seconds is not None and duration > max_seconds:
                    continue
                accepted.append(f"https://www.youtube.com/watch?v={video_id}")
                LOGGER.info("accepted video %s for %s", video_id, channel)
                if len(accepted) == count:
                    break

            page_token = search.get("nextPageToken") or ""
            if not page_token:
                break

        if not accepted:
            LOGGER.warning("no popular videos found for %s (%s)", channel, channel_id)
        else:
            LOGGER.info("selected %d videos for %s", len(accepted), channel)
        return accepted

    async def _download_video(
        self,
        video_url: str,
        channel_dir: Path,
        channel_safe_name: str,
        channel_name: str,
    ) -> None:
        LOGGER.info("downloading video: %s", video_url)
        output = await run_command(
            "python3",
            "-m",
            "yt_dlp",
            "--download-archive",
            str(self._archive_file),
            "--convert-thumbnails",
            "jpg",
            "--embed-chapters",
            "--embed-metadata",
            "--embed-thumbnail",
            "--format",
            "bv*+ba/b",
            "--format-sort",
            "res,fps,hdr:12,vcodec:vp9.2,vcodec:vp9,vcodec:av01,br",
            "--extractor-args",
            f"youtubepot-bgutilhttp:base_url={BGUTIL_PROVIDER}",
            "--no-overwrites",
            "--output",
            str(
                channel_dir
                / f"Season %(upload_date>%Y)s/{channel_safe_name} - %(upload_date>%Y-%m-%d)s - %(title).200B [%(id)s].%(ext)s"
            ),
            "--print",
            "after_move:filepath",
            "--sub-langs",
            "en",
            "--windows-filenames",
            "--write-auto-subs",
            "--write-description",
            "--write-info-json",
            "--write-thumbnail",
            "--write-subs",
            video_url,
            capture_stdout=True,
        )
        video_path = last_absolute_path_from_stdout(output)
        if video_path is None:
            LOGGER.info(
                "yt-dlp did not report downloaded path for %s; likely archived",
                video_url,
            )
            return

        info_path = video_path.with_suffix(".info.json")
        if not info_path.exists():
            LOGGER.warning("missing info json for %s", video_path)
            return

        metadata = json.loads(info_path.read_text(encoding="utf-8"))
        write_episode_nfo(video_path, metadata, channel_name)
        LOGGER.info("wrote episode nfo for %s", video_path)

    async def _download_video_with_retries(
        self,
        video_url: str,
        channel_dir: Path,
        channel_safe_name: str,
        channel_name: str,
    ) -> None:
        for attempt in range(1, 4):
            try:
                await self._download_video(
                    video_url, channel_dir, channel_safe_name, channel_name
                )
                return
            except CommandError as error:
                if is_transient_youtube_error(error) and attempt < 3:
                    delay = 60 * attempt
                    LOGGER.warning(
                        "rate limited downloading %s; retrying in %d seconds",
                        video_url,
                        delay,
                    )
                    await asyncio.sleep(delay)
                    continue
                LOGGER.warning(
                    "skipping %s after download failure: %s", video_url, error
                )
                return


async def main() -> int:
    if len(sys.argv) != 3:
        usage()
        return 2
    api_key = os.environ.get("YOUTUBE_API_KEY")
    if not api_key:
        print("error: YOUTUBE_API_KEY is not set", file=sys.stderr)
        return 2

    channels = json.loads(sys.argv[1])
    output_dir = Path(sys.argv[2])
    output_dir.mkdir(parents=True, exist_ok=True)

    async with aiohttp.ClientSession() as session:
        await wait_for_bgutil_provider(session)
        downloader = PopularVideoDownloader(session, output_dir, api_key)
        await asyncio.gather(
            *(downloader.process_channel(channel_config) for channel_config in channels)
        )

    return 0


if __name__ == "__main__":
    logging.basicConfig(
        format="%(asctime)s %(levelname)s %(message)s",
        level=logging.INFO,
    )
    sys.exit(asyncio.run(main()))
