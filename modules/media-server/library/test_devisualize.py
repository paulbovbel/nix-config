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

SCRIPT_PATH = Path(__file__).with_name("devisualize.py")
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
            ratingKey="42",
            title="Example",
            thumb="/thumb/42",
            grandparentThumb=None,
            _server=SimpleNamespace(machineIdentifier="server-id"),
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
            output_library="Music",
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

    def test_path_segments_cannot_traverse_or_exceed_component_limit(self):
        self.assertEqual(devisualize.path_segment(".."), "Unknown")
        self.assertEqual(devisualize.path_segment("a/b"), "a_b")
        self.assertLessEqual(len(devisualize.path_segment("x" * 300).encode()), 200)

    def test_plex_url_encodes_identifiers(self):
        item = SimpleNamespace(
            ratingKey="42/extra",
            _server=SimpleNamespace(machineIdentifier="server id"),
        )

        self.assertEqual(
            devisualize.item_plex_url(item),
            "https://app.plex.tv/desktop/#!/server/"
            "server%20id/details?key=%2Flibrary%2Fmetadata%2F42%2Fextra",
        )


class ProcessingTests(unittest.TestCase):
    def test_failed_stream_copy_retries_with_transcoding(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            conversion = devisualize.Conversion(
                infile=root / "source.mkv",
                outfile=root / "output.m4a",
                output_root=root,
                source_id="42:0",
                item=SimpleNamespace(title="Example"),
                output_library="Music",
                metadata=devisualize.AudioMetadata("Artist", "Album", "Track"),
            )

            with (
                mock.patch.object(
                    devisualize,
                    "artwork_for",
                    mock.AsyncMock(return_value=None),
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


if __name__ == "__main__":
    unittest.main()
