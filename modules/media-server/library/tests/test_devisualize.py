import asyncio
import importlib.util
import sys
import tempfile
import types
import unittest
from datetime import date
from pathlib import Path
from types import SimpleNamespace
from unittest import mock


requests = types.ModuleType("requests")
requests.RequestException = type("RequestException", (Exception,), {})
requests.get = mock.Mock()
sys.modules.setdefault("requests", requests)

plexapi = types.ModuleType("plexapi")
plexapi_exceptions = types.ModuleType("plexapi.exceptions")
plexapi_exceptions.NotFound = type("NotFound", (Exception,), {})
plexapi_server = types.ModuleType("plexapi.server")
plexapi_server.PlexServer = object
sys.modules.setdefault("plexapi", plexapi)
sys.modules.setdefault("plexapi.exceptions", plexapi_exceptions)
sys.modules.setdefault("plexapi.server", plexapi_server)

SCRIPT_PATH = Path(__file__).parents[1] / "scripts" / "devisualize.py"
SPEC = importlib.util.spec_from_file_location("devisualize", SCRIPT_PATH)
devisualize = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = devisualize
SPEC.loader.exec_module(devisualize)


class ProcessingManifestTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.infile = self.root / "source.mkv"
        self.infile.write_bytes(b"source")
        self.item = SimpleNamespace(
            ratingKey="42", title="Example", thumb="/thumb/42", grandparentThumb=None
        )

    def tearDown(self):
        self.temporary_directory.cleanup()

    def conversion(self, outfile=None, metadata=None):
        return devisualize.Conversion(
            infile=self.infile,
            outfile=outfile or self.root / "output.m4a",
            output_root=self.root,
            source_id="42:0",
            item=self.item,
            metadata=metadata or devisualize.AudioMetadata("Artist", "Album", "Track"),
        )

    def test_matching_manifest_skips_processing(self):
        conversion = self.conversion()
        conversion.outfile.write_bytes(b"output")
        manifest = devisualize.ProcessingManifest([conversion])
        self.assertTrue(manifest.needs_processing(conversion))
        manifest.mark_processed(conversion)
        self.assertFalse(manifest.needs_processing(conversion))
        reloaded = devisualize.ProcessingManifest([conversion])
        self.assertFalse(reloaded.needs_processing(conversion))
        self.assertNotIn(
            "plex_url", reloaded.entries[reloaded._path(conversion)]["42:0"]
        )

    def test_source_and_metadata_changes_trigger_processing(self):
        conversion = self.conversion()
        conversion.outfile.write_bytes(b"output")
        manifest = devisualize.ProcessingManifest([conversion])
        manifest.mark_processed(conversion)
        self.infile.write_bytes(b"changed source")
        self.assertTrue(manifest.needs_processing(conversion))
        manifest.mark_processed(conversion)
        changed_metadata = self.conversion(
            metadata=devisualize.AudioMetadata("Artist", "Album", "Renamed")
        )
        self.assertTrue(manifest.needs_processing(changed_metadata))

    def test_processing_version_change_triggers_processing(self):
        conversion = self.conversion()
        conversion.outfile.write_bytes(b"output")
        manifest = devisualize.ProcessingManifest([conversion])
        manifest.mark_processed(conversion)
        with mock.patch.object(
            devisualize, "PROCESSING_VERSION", devisualize.PROCESSING_VERSION + 1
        ):
            self.assertTrue(manifest.needs_processing(conversion))

    def test_changed_output_removes_previous_file(self):
        old_output = self.root / "old.m4a"
        old_output.write_bytes(b"old")
        old_conversion = self.conversion(outfile=old_output)
        manifest = devisualize.ProcessingManifest([old_conversion])
        manifest.mark_processed(old_conversion)
        new_output = self.root / "new.m4a"
        new_output.write_bytes(b"new")
        manifest.mark_processed(self.conversion(outfile=new_output))
        self.assertFalse(old_output.exists())
        self.assertTrue(new_output.exists())

    def test_invalid_manifest_is_ignored(self):
        (self.root / devisualize.MANIFEST_FILENAME).write_text("not json")
        conversion = self.conversion()
        conversion.outfile.write_bytes(b"output")
        manifest = devisualize.ProcessingManifest([conversion])
        self.assertTrue(manifest.needs_processing(conversion))


class MetadataTests(unittest.TestCase):
    def test_each_special_has_its_own_podcast(self):
        root = Path("podcasts")
        outputs = []
        for title, released, podcast in [
            ("John Mulaney: Baby J", "2023-04-25", "John Mulaney - Baby J (2023)"),
            (
                "John Mulaney - Kid Gorgeous",
                "2018-05-01",
                "John Mulaney - Kid Gorgeous (2018)",
            ),
        ]:
            metadata = devisualize.movie_metadata(title, released)
            output = devisualize.output_path(root, metadata)
            outputs.append(output)
            self.assertEqual(output.parent, root / podcast)
            self.assertTrue(output.name.startswith(released))
            self.assertEqual(metadata.album, podcast.removeprefix("John Mulaney - "))
            self.assertEqual(metadata.artist, "John Mulaney")
        self.assertNotEqual(outputs[0].parent, outputs[1].parent)

    def test_special_without_title_prefix_uses_lead_performer(self):
        item = SimpleNamespace(
            TYPE="movie",
            title="Old Baby",
            roles=[SimpleNamespace(tag="Maria Bamford")],
            originallyAvailableAt=date(2017, 5, 2),
        )
        metadata = devisualize.item_metadata(item)
        self.assertEqual(metadata.artist, "Maria Bamford")
        self.assertEqual(
            devisualize.output_path(Path("podcasts"), metadata),
            Path("podcasts/Maria Bamford - Old Baby (2017)/2017-05-02 - Old Baby.m4a"),
        )

    def test_each_jeopardy_season_has_its_own_date_ordered_podcast(self):
        outputs = []
        for season, released in [
            (40, date(2024, 7, 25)),
            (40, date(2024, 7, 26)),
            (41, date(2024, 9, 9)),
        ]:
            item = SimpleNamespace(
                TYPE="episode",
                title="Contestants",
                grandparentTitle="Jeopardy!",
                parentTitle=f"Season {season}",
                parentIndex=season,
                index=1,
                originallyAvailableAt=released,
            )
            metadata = devisualize.item_metadata(item)
            outputs.append(devisualize.output_path(Path("podcasts"), metadata))
            self.assertEqual(metadata.album, f"Season {season}")
            self.assertEqual(metadata.track_number, 1)
            self.assertEqual(metadata.season_number, season)
        self.assertEqual(outputs[0].parent, outputs[1].parent)
        self.assertNotEqual(outputs[1].parent, outputs[2].parent)
        self.assertEqual(outputs, sorted(outputs))
        self.assertTrue(outputs[0].name.startswith("2024-07-25"))

    def test_season_number_is_used_when_season_title_is_missing(self):
        metadata = devisualize.episode_metadata(
            SimpleNamespace(title="Episode", grandparentTitle="Show", parentIndex=2)
        )
        self.assertEqual(metadata.album, "Season 2")

    def test_podcast_title_does_not_repeat_author(self):
        metadata = devisualize.movie_metadata(
            "Bill Burr: You People Are All the Same.", "2012-08-16"
        )
        self.assertEqual(metadata.album, "You People Are All the Same. (2012)")
        self.assertEqual(metadata.artist, "Bill Burr")

    def test_identical_titles_from_different_authors_have_separate_folders(self):
        root = Path("podcasts")
        first = devisualize.movie_metadata("First Comedian: Special", "2020")
        second = devisualize.movie_metadata("Second Comedian: Special", "2020")
        self.assertEqual(first.album, second.album)
        self.assertNotEqual(
            devisualize.output_path(root, first).parent,
            devisualize.output_path(root, second).parent,
        )

    def test_release_date_prefers_full_date_and_falls_back_to_year(self):
        self.assertEqual(
            devisualize.item_release_date(
                SimpleNamespace(originallyAvailableAt=date(2020, 4, 3), year=2019)
            ),
            "2020-04-03",
        )
        self.assertEqual(
            devisualize.item_release_date(
                SimpleNamespace(originallyAvailableAt=None, year=2019)
            ),
            "2019",
        )

    def test_summaries_are_preserved_without_plex_links(self):
        for item_type in ["movie", "episode"]:
            item = SimpleNamespace(
                TYPE=item_type,
                title="Example",
                summary="Contestant details or a special summary.",
            )
            self.assertEqual(devisualize.item_metadata(item).description, item.summary)
        item.summary += " https://app.plex.tv/desktop/#!/server/id/details?key=42"
        self.assertEqual(
            devisualize.item_metadata(item).description,
            "Contestant details or a special summary.",
        )
        self.assertIsNone(devisualize.item_description(SimpleNamespace()))

    def test_local_plex_and_native_links_are_removed(self):
        self.assertEqual(
            devisualize.item_description(
                SimpleNamespace(
                    summary="Summary https://plex:32400/library/metadata/42 plex://42"
                )
            ),
            "Summary",
        )

    def test_path_segments_cannot_traverse_or_exceed_component_limit(self):
        self.assertEqual(devisualize.path_segment(".."), "Unknown")
        self.assertEqual(devisualize.path_segment("a/b"), "a_b")
        self.assertLessEqual(len(devisualize.path_segment("x" * 300).encode()), 200)

    def test_collection_discovery_only_reads_source_libraries(self):
        item = SimpleNamespace(
            TYPE="movie",
            title="John Mulaney: Baby J",
            ratingKey="42",
            originallyAvailableAt=date(2023, 4, 25),
            media=[
                SimpleNamespace(parts=[SimpleNamespace(file="/plex/movies/baby.mkv")])
            ],
        )
        section = SimpleNamespace(
            collection=mock.Mock(return_value=SimpleNamespace(items=lambda: [item]))
        )
        plex = SimpleNamespace(
            library=SimpleNamespace(section=mock.Mock(return_value=section))
        )
        runtime = devisualize.RuntimeConfig(
            Path("/media"), Path("/plex"), Path("/podcasts"), "http://plex", False
        )
        conversions = devisualize.collect_conversions(
            plex, runtime, [devisualize.CONFIG[0]]
        )
        plex.library.section.assert_called_once_with("Movies")
        self.assertEqual(conversions[0].infile, Path("/media/movies/baby.mkv"))
        self.assertEqual(
            conversions[0].outfile,
            Path("/podcasts/John Mulaney - Baby J (2023)/2023-04-25 - Baby J.m4a"),
        )


class ProcessingTests(unittest.TestCase):
    def conversion(self, root):
        return devisualize.Conversion(
            infile=root / "source.mkv",
            outfile=root / "output.m4a",
            output_root=root,
            source_id="42:0",
            item=SimpleNamespace(title="Example"),
            metadata=devisualize.AudioMetadata("Artist", "Album", "Track"),
        )

    def test_failed_stream_copy_retries_with_transcoding(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            conversion = self.conversion(root)
            with (
                mock.patch.object(
                    devisualize, "artwork_for", mock.AsyncMock(return_value=None)
                ),
                mock.patch.object(
                    devisualize,
                    "write_audio",
                    mock.AsyncMock(
                        side_effect=[devisualize.FFmpegError("copy failed"), None]
                    ),
                ) as write_audio,
            ):
                processed = asyncio.run(
                    devisualize.process_conversion(conversion, root / "artwork")
                )
            self.assertIs(processed, conversion)
            self.assertEqual(write_audio.await_count, 2)
            self.assertFalse(
                write_audio.await_args_list[0].kwargs.get("transcode", False)
            )
            self.assertTrue(write_audio.await_args_list[1].kwargs["transcode"])

    def test_audio_metadata_does_not_include_source_links(self):
        with tempfile.TemporaryDirectory() as directory:
            conversion = self.conversion(Path(directory))
            process = SimpleNamespace(
                returncode=0, communicate=mock.AsyncMock(return_value=(b"", b""))
            )
            with (
                mock.patch.object(
                    asyncio,
                    "create_subprocess_exec",
                    mock.AsyncMock(return_value=process),
                ) as spawn,
                mock.patch.object(devisualize.os, "replace"),
            ):
                asyncio.run(devisualize.write_audio(conversion))
            args = spawn.call_args.args
            self.assertIn("-map_metadata", args)
            self.assertFalse(
                any("plex" in arg or arg.startswith("comment=") for arg in args)
            )

    def test_audio_embeds_description_and_season_episode_identifiers(self):
        with tempfile.TemporaryDirectory() as directory:
            conversion = self.conversion(Path(directory))
            conversion = devisualize.dataclasses.replace(
                conversion,
                metadata=devisualize.AudioMetadata(
                    "Jeopardy!",
                    "Season 41",
                    "Contestants",
                    track_number=12,
                    release_date="2024-09-24",
                    season_number=41,
                    description="Alice vs. Bob vs. Charlie.",
                ),
            )
            process = SimpleNamespace(
                returncode=0, communicate=mock.AsyncMock(return_value=(b"", b""))
            )
            with (
                mock.patch.object(
                    asyncio,
                    "create_subprocess_exec",
                    mock.AsyncMock(return_value=process),
                ) as spawn,
                mock.patch.object(devisualize.os, "replace"),
            ):
                asyncio.run(devisualize.write_audio(conversion))
            args = spawn.call_args.args
            for tag in [
                "album=Season 41",
                "track=12",
                "disc=41",
                "date=2024-09-24",
                "comment=Alice vs. Bob vs. Charlie.",
            ]:
                self.assertIn(tag, args)


class PodcastCoverTests(unittest.TestCase):
    def conversion(self, root, item, artist="Maria Bamford"):
        return devisualize.Conversion(
            infile=root / "source.mkv",
            outfile=root / artist / "special.m4a",
            output_root=root,
            source_id="42:0",
            item=item,
            metadata=devisualize.AudioMetadata(artist, artist, "Special"),
        )

    def movie(self):
        return SimpleNamespace(
            TYPE="movie",
            thumb="/special-poster",
            roles=[
                SimpleNamespace(tag="Someone Else", thumb="/other"),
                SimpleNamespace(tag="Maria Bamford", thumb="/portrait"),
            ],
            _server=SimpleNamespace(
                url=mock.Mock(return_value="https://plex/special-poster")
            ),
        )

    def test_special_cover_is_downloaded_once_and_existing_cover_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            item = self.movie()
            conversion = self.conversion(Path(directory), item)
            response = SimpleNamespace(
                content=b"portrait", raise_for_status=mock.Mock()
            )
            with mock.patch.object(
                devisualize.requests, "get", return_value=response
            ) as get:
                devisualize.ensure_podcast_covers([conversion, conversion])
                get.assert_called_once_with("https://plex/special-poster", timeout=30)
                item._server.url.assert_called_once_with(
                    "/special-poster", includeToken=True
                )
                cover = conversion.outfile.parent / "cover.jpg"
                self.assertEqual(cover.read_bytes(), b"portrait")
                cover.write_bytes(b"custom cover")
                devisualize.ensure_podcast_covers([conversion])
                self.assertEqual(get.call_count, 1)
                self.assertEqual(cover.read_bytes(), b"custom cover")

    def test_jeopardy_cover_uses_show_artwork(self):
        item = SimpleNamespace(
            TYPE="episode",
            thumb="/episode",
            grandparentThumb="/show",
            _server=SimpleNamespace(url=mock.Mock(return_value="https://plex/show")),
        )
        conversion = self.conversion(Path("podcasts"), item, "Jeopardy!")
        self.assertEqual(
            devisualize.podcast_artwork_url(conversion), "https://plex/show"
        )
        item._server.url.assert_called_once_with("/show", includeToken=True)

    def test_season_cover_is_preferred_over_show_and_episode_artwork(self):
        item = SimpleNamespace(
            TYPE="episode",
            thumb="/episode",
            parentThumb="/season",
            grandparentThumb="/show",
            _server=SimpleNamespace(url=mock.Mock(return_value="https://plex/season")),
        )
        conversion = self.conversion(Path("podcasts"), item, "Jeopardy! - Season 41")
        self.assertEqual(
            devisualize.podcast_artwork_url(conversion), "https://plex/season"
        )
        item._server.url.assert_called_once_with("/season", includeToken=True)

    def test_missing_artwork_can_be_found_in_another_episode_of_the_season(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            missing = self.movie()
            missing.thumb = None
            conversions = [
                self.conversion(root, missing),
                self.conversion(root, self.movie()),
            ]
            response = SimpleNamespace(
                content=b"portrait", raise_for_status=mock.Mock()
            )
            with mock.patch.object(
                devisualize.requests, "get", return_value=response
            ) as get:
                devisualize.ensure_podcast_covers(conversions)
                self.assertEqual(get.call_count, 1)
            self.assertTrue((conversions[0].outfile.parent / "cover.jpg").exists())

    def test_failed_cover_download_is_retried_on_next_run(self):
        with tempfile.TemporaryDirectory() as directory:
            conversion = self.conversion(Path(directory), self.movie())
            response = SimpleNamespace(
                content=b"portrait", raise_for_status=mock.Mock()
            )
            with mock.patch.object(
                devisualize.requests,
                "get",
                side_effect=[devisualize.requests.RequestException("failed"), response],
            ):
                devisualize.ensure_podcast_covers([conversion])
                self.assertFalse((conversion.outfile.parent / "cover.jpg").exists())
                devisualize.ensure_podcast_covers([conversion])
            self.assertEqual(
                (conversion.outfile.parent / "cover.jpg").read_bytes(), b"portrait"
            )
            self.assertEqual(list(conversion.outfile.parent.glob("*.partial")), [])


if __name__ == "__main__":
    unittest.main()
