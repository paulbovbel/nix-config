import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "mam_update", Path(__file__).parents[1] / "scripts" / "mam-update.py"
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
            "container_request",
            side_effect=[
                mam.HttpResponse("192.0.2.1", 200),
                mam.HttpResponse(json.dumps(body), status, retry_after),
            ],
        ):
            mam.update_mam_ip(self.target, "new-id")

    def test_cooldown_keeps_registration_pending_then_retries(self):
        with patch.object(mam.time, "time", return_value=1000):
            self.update(
                429, {"Success": False, "msg": "Last change too recent"}, "7200"
            )
        self.assertFalse((self.path / "mam.ip.wg0").exists())
        self.assertEqual(
            mam.read_text(self.target.state.cookie_fingerprint),
            mam.fingerprint("new-id"),
        )
        self.assertEqual(
            (self.path / "mam.retry-after.wg0").read_text().strip(), "8200"
        )
        with (
            patch.object(mam.time, "time", return_value=2000),
            patch.object(
                mam,
                "container_request",
                return_value=mam.HttpResponse("192.0.2.1", 200),
            ) as request,
            patch.object(mam, "remove_file") as remove,
            patch("builtins.print") as log,
        ):
            mam.update_mam_ip(self.target, "new-id")
        remove.assert_not_called()
        log.assert_called_once_with(
            "MAM IP update deferred for wg0; cooldown still active"
        )
        request.assert_called_once()
        with patch.object(mam.time, "time", return_value=8201):
            self.update(200, {"Success": True})
        self.assertEqual((self.path / "mam.ip.wg0").read_text().strip(), "192.0.2.1")
        self.assertEqual(
            self.target.state.cookie_fingerprint.read_text().strip(),
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

    def test_egress_waits_for_interface_then_registers(self):
        with (
            patch.object(
                mam,
                "podman_exec",
                side_effect=[
                    subprocess.CalledProcessError(45, "curl", stderr="bind failed"),
                    "192.0.2.1\n\n200\n",
                    '{"Success":true}\n200\n',
                ],
            ) as execute,
            patch.object(mam.time, "sleep") as sleep,
        ):
            mam.update_mam_ip(self.target, "new-id")
        sleep.assert_called_once_with(mam.EGRESS_RETRY_DELAY_SECONDS)
        self.assertEqual((self.path / "mam.ip.wg0").read_text().strip(), "192.0.2.1")
        for call in execute.call_args_list:
            args = call.args[1]
            self.assertEqual(args[args.index("--interface") + 1], "wg0")
        self.assertEqual(execute.call_args_list[-1].args[1][-1], mam.MAM_API)

    def test_egress_timeout_preserves_cached_ip_without_registering(self):
        cached_ip = self.path / "mam.ip.wg0"
        cached_ip.write_text("192.0.2.1\n")
        mam.write_private(
            self.target.state.cookie_fingerprint, mam.fingerprint("new-id")
        )
        with (
            patch.object(
                mam,
                "podman_exec",
                side_effect=subprocess.CalledProcessError(45, "curl"),
            ) as execute,
            patch.object(mam.time, "sleep") as sleep,
            self.assertRaisesRegex(RuntimeError, "timed out waiting for egress"),
        ):
            mam.update_mam_ip(self.target, "new-id")
        self.assertEqual(execute.call_count, mam.EGRESS_RETRY_COUNT)
        self.assertEqual(sleep.call_count, mam.EGRESS_RETRY_COUNT - 1)
        self.assertEqual(cached_ip.read_text(), "192.0.2.1\n")
        for call in execute.call_args_list:
            self.assertEqual(call.args[1][-1], mam.IP_CHECK_URL)

    def test_egress_does_not_retry_http_errors_or_invalid_responses(self):
        for response in ["Forbidden\n403\n", "invalid IP\n200\n"]:
            with (
                self.subTest(response=response),
                patch.object(mam, "podman_exec", side_effect=[response]) as execute,
                patch.object(mam.time, "sleep") as sleep,
                self.assertRaises(RuntimeError),
            ):
                mam.wait_for_egress_ip(self.target)
            execute.assert_called_once()
            sleep.assert_not_called()

    def test_retry_after_date_and_fallback(self):
        with patch.object(mam.time, "time", return_value=0):
            self.assertEqual(mam.mam_retry_at("Thu, 01 Jan 1970 02:00:00 GMT"), 7200)
            self.assertEqual(mam.mam_retry_at(""), 3600)
            self.assertEqual(mam.mam_retry_at("invalid"), 3600)

    def test_credential_rotation_discards_old_cookie_even_for_same_ip(self):
        state = self.target.state
        mam.write_private(state.cached_ip, "192.0.2.1")
        mam.write_private(state.cookie_jar, "old-cookie")
        mam.write_private(state.cookie_fingerprint, mam.fingerprint("old-id"))
        with patch.object(
            mam,
            "container_request",
            side_effect=[
                mam.HttpResponse("192.0.2.1", 200),
                mam.HttpResponse('{"Success":true}', 200),
            ],
        ) as request:
            mam.update_mam_ip(self.target, "new-id")
        self.assertEqual(request.call_count, 2)
        self.assertEqual(request.call_args.kwargs["cookie"], "mam_id=new-id")
        self.assertEqual(
            request.call_args.kwargs["cookie_jar"], "/config/mam.cookies.wg0"
        )
        self.assertFalse(state.cookie_jar.exists())
        self.assertEqual(mam.read_text(state.cached_ip), "192.0.2.1")
        self.assertEqual(
            mam.read_text(state.cookie_fingerprint), mam.fingerprint("new-id")
        )

    def test_http_metadata_preserves_error_body(self):
        with patch.object(
            mam, "podman_exec", return_value='{"Success":false}\n429\n3600'
        ) as execute:
            result = mam.container_request(
                "qbittorrent", mam.MAM_API, description="MAM", check_status=False
            )
        self.assertEqual(result, mam.HttpResponse('{"Success":false}', 429, "3600"))
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
                "container_request",
                side_effect=[
                    mam.HttpResponse("192.0.2.1", 200),
                    mam.HttpResponse(
                        json.dumps({"Success": False, "msg": "Last change too recent"}),
                        429,
                        "",
                    ),
                    mam.HttpResponse("192.0.2.2", 200),
                    mam.HttpResponse('{"Success":true}', 200),
                ],
            ),
        ):
            mam.main()
        apps.assert_called_once()
        self.assertTrue((self.path / "mam.ip.eth0").exists())
        self.assertFalse((self.path / "mam.ip.wg0").exists())


class ReadinessTests(unittest.TestCase):
    def test_api_retries_transport_http_and_json_failures(self):
        with (
            patch.object(
                mam,
                "podman_exec",
                side_effect=[
                    subprocess.CalledProcessError(7, "curl"),
                    "Unavailable\n503\n",
                    "not json\n200\n",
                    '[{"id": 5}]\n200\n',
                ],
            ) as execute,
            patch.object(mam.time, "sleep") as sleep,
        ):
            result = mam.wait_for_json(
                lambda: mam.ContainerHttpClient("autobrr").get(mam.AUTOBRR_API_URL),
                "autobrr API",
            )
        self.assertEqual(result, [{"id": 5}])
        self.assertEqual(execute.call_count, 4)
        self.assertEqual(sleep.call_count, 3)

    def test_api_exhaustion_reports_last_failure(self):
        with (
            patch.object(
                mam, "podman_exec", return_value="Unavailable\n503\n"
            ) as execute,
            patch.object(mam.time, "sleep") as sleep,
            self.assertRaisesRegex(
                RuntimeError, "timed out waiting for autobrr API.*503"
            ),
        ):
            mam.wait_for_json(
                lambda: mam.ContainerHttpClient("autobrr").get(mam.AUTOBRR_API_URL),
                "autobrr API",
            )
        self.assertEqual(execute.call_count, mam.API_RETRY_COUNT)
        self.assertEqual(sleep.call_count, mam.API_RETRY_COUNT - 1)

    def test_mutations_are_not_retried(self):
        with (
            patch.object(
                mam,
                "podman_exec",
                side_effect=subprocess.CalledProcessError(28, "curl"),
            ) as execute,
            self.assertRaises(mam.ContainerRequestError),
        ):
            mam.ContainerHttpClient("autobrr").put_json(f"{mam.AUTOBRR_API_URL}/5", {})
        execute.assert_called_once()

    def test_request_preserves_body_and_container_options(self):
        with patch.object(
            mam, "podman_exec", return_value='{"value":\n42}\n200\n'
        ) as execute:
            http = mam.ContainerHttpClient(
                "jackett",
                user="1000:1000",
                interface="eth0",
                headers=("X-Test: value",),
            )
            response = http.get(
                mam.MAM_API,
                cookie="/config/cookies",
                cookie_jar="/config/cookies",
            )
        self.assertEqual(response.json(), {"value": 42})
        self.assertEqual(execute.call_args.args[0], "jackett")
        self.assertEqual(execute.call_args.kwargs["user"], "1000:1000")
        args = execute.call_args.args[1]
        for option, value in [
            ("--header", "X-Test: value"),
            ("--interface", "eth0"),
            ("--cookie", "/config/cookies"),
            ("--cookie-jar", "/config/cookies"),
        ]:
            self.assertEqual(args[args.index(option) + 1], value)


class AppUpdateTests(unittest.TestCase):
    def test_app_fingerprint_commits_only_after_all_updates_succeed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            target = mam.MamTarget("jackett", "1000:1000", "eth0", path)
            # IP credential state must not suppress pending application updates.
            mam.write_private(
                target.state.cookie_fingerprint, mam.fingerprint("new-id")
            )
            with (
                patch.object(mam, "update_jackett") as jackett,
                patch.object(mam, "update_autobrr"),
                patch.object(mam, "update_prowlarr"),
                patch.object(
                    mam,
                    "update_shelfmark",
                    side_effect=[RuntimeError("not ready"), None],
                ) as shelfmark,
            ):

                def update():
                    mam.update_indexer_apps(
                        target,
                        "new-id",
                        shelfmark_config_dir=path,
                        prowlarr_config_dir=path,
                    )

                with self.assertRaisesRegex(RuntimeError, "not ready"):
                    update()
                self.assertFalse(target.state.app_fingerprint.exists())
                update()
                self.assertEqual(
                    mam.read_text(target.state.app_fingerprint),
                    mam.fingerprint("new-id"),
                )
                update()
                self.assertEqual(jackett.call_count, 2)
                self.assertEqual(shelfmark.call_count, 2)

    def test_autobrr_updates_cookie_preserving_other_settings(self):
        indexer = {"id": 5, "settings": {"cookie": "old", "other": True}}
        with (
            patch.object(mam, "mam_id_from_env", return_value="test-token"),
            patch.object(
                mam,
                "podman_exec",
                side_effect=[
                    '[{"id":5,"identifier":"myanonamouse"}]\n200\n',
                    f"{json.dumps(indexer)}\n200\n",
                    "\n204\n",
                ],
            ) as execute,
        ):
            mam.update_autobrr("new-id")
        update = execute.call_args
        self.assertEqual(update.args[0], "autobrr")
        self.assertEqual(update.args[1][-1], f"{mam.AUTOBRR_API_URL}/5")
        self.assertIn("PUT", update.args[1])
        self.assertIn("Content-Type: application/json", update.args[1])
        self.assertIn("X-API-Token: test-token", update.args[1])
        self.assertEqual(
            json.loads(update.kwargs["input_text"])["settings"],
            {"cookie": "mam_id=new-id;", "other": True},
        )

    def test_prowlarr_updates_only_mam_indexer(self):
        indexers = [
            {"id": 1, "implementation": "Other"},
            {
                "id": 3,
                "implementation": "MyAnonamouse",
                "fields": [{"name": "mamId", "value": "old"}],
            },
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "config.xml").write_text("<Config><ApiKey>test</ApiKey></Config>")
            with patch.object(
                mam,
                "podman_exec",
                side_effect=[f"{json.dumps(indexers)}\n200\n", "\n204\n"],
            ) as execute:
                mam.update_prowlarr(path, "new-id")
        self.assertEqual(execute.call_count, 2)
        update = execute.call_args
        self.assertEqual(update.args[0], "prowlarr")
        self.assertEqual(update.args[1][-1], f"{mam.PROWLARR_API_URL}/3")
        self.assertEqual(
            json.loads(update.kwargs["input_text"])["fields"],
            [{"name": "mamId", "value": "new-id"}],
        )


if __name__ == "__main__":
    unittest.main()
