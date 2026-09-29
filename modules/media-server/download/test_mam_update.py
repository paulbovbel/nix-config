import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "mam_update", Path(__file__).with_name("mam-update.py")
)
mam = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = mam
spec.loader.exec_module(mam)


class MamCooldownTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name)
        self.target = mam.MamTarget("qbittorrent", "1000:1000", "wg0", self.path)

    def update(self, status, body, retry_after=""):
        with patch.object(
            mam,
            "curl",
            side_effect=["192.0.2.1", (json.dumps(body), status, retry_after)],
        ):
            changed = mam.read_text(
                mam.mam_id_fingerprint_path(self.target)
            ) != mam.fingerprint("new-id")
            mam.update_mam_ip(self.target, "new-id", changed)

    def test_cooldown_keeps_registration_pending_then_retries(self):
        with patch.object(mam.time, "time", return_value=1000):
            self.update(
                429, {"Success": False, "msg": "Last change too recent"}, "7200"
            )
        self.assertFalse((self.path / "mam.ip.wg0").exists())
        self.assertEqual(
            mam.read_text(mam.mam_id_fingerprint_path(self.target)),
            mam.fingerprint("new-id"),
        )
        self.assertEqual(
            (self.path / "mam.retry-after.wg0").read_text().strip(), "8200"
        )
        with (
            patch.object(mam.time, "time", return_value=2000),
            patch.object(mam, "curl", return_value="192.0.2.1") as curl,
            patch.object(mam, "remove_file") as remove,
            patch("builtins.print") as log,
        ):
            changed = mam.read_text(
                mam.mam_id_fingerprint_path(self.target)
            ) != mam.fingerprint("new-id")
            self.assertFalse(changed)
            mam.update_mam_ip(self.target, "new-id", changed)
        remove.assert_not_called()
        log.assert_called_once_with(
            "MAM IP update deferred for wg0; cooldown still active"
        )
        curl.assert_called_once()
        with patch.object(mam.time, "time", return_value=8201):
            self.update(200, {"Success": True})
        self.assertEqual((self.path / "mam.ip.wg0").read_text().strip(), "192.0.2.1")
        self.assertEqual(
            mam.mam_id_fingerprint_path(self.target).read_text().strip(),
            mam.fingerprint("new-id"),
        )
        self.assertFalse((self.path / "mam.retry-after.wg0").exists())

    def test_other_errors_are_not_suppressed(self):
        for status, body in [
            (403, {"Success": False, "msg": "Invalid session"}),
            (429, {"Success": False, "msg": "Other limit"}),
            (200, {"Success": False, "msg": "Rejected"}),
            (200, {"success": False}),
            (200, {}),
            (200, "unexpected response"),
        ]:
            with (
                self.subTest(status=status, body=body),
                self.assertRaises(RuntimeError),
            ):
                self.update(status, body)
            self.assertFalse((self.path / "mam.ip.wg0").exists())

    def test_retry_after_date_and_fallback(self):
        with patch.object(mam.time, "time", return_value=0):
            self.assertEqual(mam.mam_retry_at("Thu, 01 Jan 1970 02:00:00 GMT"), 7200)
            self.assertEqual(mam.mam_retry_at(""), 3600)
            self.assertEqual(mam.mam_retry_at("invalid"), 3600)

    def test_http_metadata_preserves_error_body(self):
        with patch.object(
            mam, "podman_exec", return_value='{"Success":false}\n429\n3600'
        ) as execute:
            result = mam.curl(
                "qbittorrent", mam.MAM_API, description="MAM", response_metadata=True
            )
        self.assertEqual(result, ('{"Success":false}', 429, "3600"))
        self.assertNotIn("--fail-with-body", execute.call_args.args[1])
        self.assertNotIn("--fail", execute.call_args.args[1])

    def test_main_continues_after_torrent_cooldown(self):
        indexer = mam.MamTarget("jackett", "1000:1000", "eth0", self.path)
        from argparse import Namespace

        args = Namespace(shelfmark_config_dir=self.path, prowlarr_config_dir=self.path)
        with (
            patch.object(mam, "parse_args", return_value=(self.target, indexer, args)),
            patch.object(mam, "mam_id_from_env", return_value="new-id"),
            patch.object(mam, "update_indexer_apps") as apps,
            patch.object(
                mam,
                "curl",
                side_effect=[
                    "192.0.2.1",
                    (
                        json.dumps({"Success": False, "msg": "Last change too recent"}),
                        429,
                        "",
                    ),
                    "192.0.2.2",
                    ('{"Success":true}', 200, ""),
                ],
            ),
        ):
            mam.main()
        apps.assert_called_once()
        self.assertTrue((self.path / "mam.ip.eth0").exists())
        self.assertFalse((self.path / "mam.ip.wg0").exists())


if __name__ == "__main__":
    unittest.main()
