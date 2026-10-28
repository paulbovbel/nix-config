import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPTS = Path(__file__).parents[1] / "scripts"


def load(name):
    spec = importlib.util.spec_from_file_location(
        name.replace("-", "_"), Path(__file__).parents[1] / "scripts" / f"{name}.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


sync = load("qbittorrent-port-sync")


def responses(*values):
    """Patch the JSON transport, returning each value for successive calls."""
    return patch.object(sync, "request", side_effect=list(values))


class PortSyncTests(unittest.IsolatedAsyncioTestCase):
    def test_binds_the_tunnel_only_while_a_forward_is_active(self):
        self.assertEqual(sync.preferences(12345)["current_network_interface"], "wg0")
        self.assertEqual(sync.preferences(0)["current_network_interface"], "lo")

    def test_claims_no_listen_port_without_a_forward(self):
        # qBittorrent reports random_port true whenever no port is set, so
        # asking for listen_port 0 with random_port false never converges and
        # the reconciler rewrites preferences on every poll.
        self.assertEqual(
            sync.preferences(0).keys(), {"current_network_interface", "upnp"}
        )

    async def test_converges_against_live_idle_preferences(self):
        # Shape observed on the host while no forward was active.
        idle = {
            "listen_port": 0,
            "current_network_interface": "lo",
            "current_interface_address": "",
            "random_port": True,
            "upnp": False,
        }
        with responses(idle) as request:
            self.assertIsNone(await sync.reconcile(0))
        request.assert_called_once()

    def test_rejects_out_of_range_and_non_integer_ports(self):
        for invalid in (65536, -1, "bad", True, None, 1.0):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                sync.preferences(invalid)

    async def test_reads_both_gluetun_response_shapes(self):
        for value, expected in (
            ({"ports": [12345], "port": 12345}, 12345),
            ({"ports": [12345, 23456]}, 12345),
            ({"ports": []}, 0),
            ({"port": 12345}, 12345),
            ({"port": 0}, 0),
        ):
            with self.subTest(value=value), responses(value):
                self.assertEqual(await sync.forwarded_port(), expected)

    async def test_rejects_an_invalid_forwarded_port(self):
        with responses({"port": 99999}), self.assertRaises(ValueError):
            await sync.forwarded_port()
        with responses({}), self.assertRaises(KeyError):
            await sync.forwarded_port()

    async def test_applies_the_forwarded_port_to_qbittorrent(self):
        with responses({}, None) as request:
            self.assertEqual(await sync.reconcile(12345), sync.preferences(12345))
        self.assertEqual(request.call_count, 2)
        url, body = request.call_args.args
        self.assertTrue(url.endswith("/setPreferences"))
        self.assertIn(b"12345", body)
        self.assertIn(b"wg0", body)

    async def test_skips_a_redundant_write(self):
        with responses(sync.preferences(12345)) as request:
            self.assertIsNone(await sync.reconcile(12345))
        request.assert_called_once()

    async def test_rewrites_after_an_independent_qbittorrent_restart(self):
        # A restarted qBittorrent reports the loopback binding its startup hook
        # wrote, so the next poll restores the live forward without extra state.
        with responses(sync.preferences(0), None) as request:
            self.assertEqual(await sync.reconcile(12345), sync.preferences(12345))
        self.assertIn(b"12345", request.call_args.args[1])

    async def test_polls_until_stopped_and_tracks_each_change(self):
        applied = []
        stopped = sync.asyncio.Event()

        async def observe(port):
            applied.append(port)
            if len(applied) == 4:
                stopped.set()
            return sync.preferences(port)

        with (
            patch.object(sync, "forwarded_port", side_effect=[0, 12345, 12345, 0]),
            patch.object(sync, "reconcile", side_effect=observe),
            patch.object(sync, "POLL_SECONDS", 0),
        ):
            # The broad except in run() would otherwise swallow a bug in the
            # success path, such as logging a key preferences() does not set.
            with self.assertNoLogs(sync.LOG, level="WARNING"):
                await sync.run(stopped)
        self.assertEqual(applied, [0, 12345, 12345, 0])

    async def test_retries_through_an_api_outage(self):
        stopped = sync.asyncio.Event()
        attempts = []

        async def flaky():
            attempts.append(len(attempts))
            if len(attempts) < 3:
                raise OSError("not ready")
            stopped.set()
            return 12345

        with (
            patch.object(sync, "forwarded_port", side_effect=flaky),
            patch.object(
                sync, "reconcile", return_value=sync.preferences(12345)
            ) as apply,
            patch.object(sync, "POLL_SECONDS", 0),
        ):
            await sync.run(stopped)
        self.assertEqual(len(attempts), 3)
        apply.assert_awaited_once_with(12345)

    async def test_survives_a_malformed_control_api_response(self):
        stopped = sync.asyncio.Event()
        values = [42, {"ports": "nonsense"}, {"port": 12345}]

        async def answer(*_args):
            value = values.pop(0)
            if not values:
                stopped.set()
            return value

        with (
            patch.object(sync, "request", side_effect=answer),
            patch.object(sync, "reconcile", return_value=None),
            patch.object(sync, "POLL_SECONDS", 0),
        ):
            await sync.run(stopped)
        self.assertEqual(values, [])

    async def test_stops_without_contacting_either_api(self):
        stopped = sync.asyncio.Event()
        stopped.set()
        with patch.object(sync, "forwarded_port") as query:
            await sync.run(stopped)
        query.assert_not_called()

    async def test_wakes_immediately_when_stopped_mid_wait(self):
        stopped = sync.asyncio.Event()
        task = sync.asyncio.create_task(sync.sleep_unless_stopped(stopped, 30))
        await sync.asyncio.sleep(0)
        stopped.set()
        await sync.asyncio.wait_for(task, timeout=1)

    def test_loopback_only_endpoints_bypassing_any_inherited_proxy(self):
        self.assertTrue(sync.GLUETUN_PORTFORWARD.startswith("http://127.0.0.1:8000/"))
        self.assertTrue(sync.QBITTORRENT_API.startswith("http://127.0.0.1:8080/"))
        with patch.object(sync, "build_opener") as build_opener:
            build_opener.return_value.open.return_value.__enter__ = lambda self: (
                FakeResponse()
            )
            build_opener.return_value.open.return_value.__exit__ = lambda self, *_: (
                False
            )
            sync.fetch(sync.GLUETUN_PORTFORWARD)
        handler = build_opener.call_args.args[0]
        self.assertIsInstance(handler, sync.ProxyHandler)
        self.assertEqual(handler.proxies, {})


class FakeResponse:
    def read(self, _limit):
        return json.dumps({"port": 0}).encode()


class LeaseGuardTests(unittest.TestCase):
    """PIA issues a forwarding lease per server; it is void on a different one."""

    def run_guard(self, server_name, gluetun_dir):
        name_file = gluetun_dir / "server-name"
        name_file.write_text(f"{server_name}\n")
        return subprocess.run(
            [
                "bash",
                str(SCRIPTS / "pia-lease-guard.sh"),
                str(name_file),
                str(gluetun_dir),
            ],
            text=True,
            capture_output=True,
            check=True,
        )

    def test_keeps_the_lease_while_the_server_is_unchanged(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            lease = root / "piaportforward.json"

            self.run_guard("Server-10960-4a", root)
            lease.write_text("lease")
            self.run_guard("Server-10960-4a", root)

            self.assertEqual(lease.read_text(), "lease")

    def test_discards_the_lease_when_the_server_changes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            lease = root / "piaportforward.json"

            self.run_guard("Server-10960-4a", root)
            lease.write_text("lease")
            self.run_guard("Server-11527-3a", root)

            self.assertFalse(lease.exists())
            # A third run on the new server must not discard the fresh lease.
            lease.write_text("new lease")
            self.run_guard("Server-11527-3a", root)
            self.assertEqual(lease.read_text(), "new lease")

    def test_first_run_records_the_server_without_an_existing_lease(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.run_guard("Server-10960-4a", root)
            marker = root / ".registered-server"
            self.assertEqual(marker.read_text(), "Server-10960-4a\n")
            self.assertEqual(marker.stat().st_mode & 0o777, 0o600)

    def test_rejects_wrong_argument_count(self):
        result = subprocess.run(
            ["bash", str(SCRIPTS / "pia-lease-guard.sh"), "only-one"],
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("usage:", result.stderr)


if __name__ == "__main__":
    unittest.main()
