import contextlib
import io
import json
import unittest
from unittest import mock

import graphical_sessions


def completed(stdout: str = "", returncode: int = 0) -> mock.Mock:
    return mock.Mock(stdout=stdout, stderr="", returncode=returncode)


class GraphicalSessionsTest(unittest.TestCase):
    def test_default_sessions_resolve_each_account_independently(self) -> None:
        account_paths = {
            "alice": "/org/freedesktop/Accounts/User1000",
            "bob": "/org/freedesktop/Accounts/User1001",
        }
        applied = {}

        def run(*command: str) -> mock.Mock:
            if "FindUserByName" in command:
                return completed(json.dumps({"data": [account_paths[command[-1]]]}))
            applied[(command[4], command[6])] = command[-1]
            return completed()

        with mock.patch.object(graphical_sessions, "_run", side_effect=run):
            graphical_sessions.set_default_sessions(
                {"alice": "hyprland", "bob": "gnome"}
            )

        self.assertEqual(
            applied,
            {
                (account_paths["alice"], "SetSession"): "hyprland",
                (account_paths["alice"], "SetSessionType"): "wayland",
                (account_paths["bob"], "SetSession"): "gnome",
                (account_paths["bob"], "SetSessionType"): "wayland",
            },
        )

    def test_default_sessions_stop_when_account_lookup_fails(self) -> None:
        with mock.patch.object(
            graphical_sessions, "_run", return_value=completed(returncode=1)
        ) as run:
            with self.assertRaisesRegex(
                RuntimeError, "failed to resolve account alice"
            ):
                graphical_sessions.set_default_sessions({"alice": "gnome"})
        self.assertEqual(run.call_count, 1)

    def test_default_sessions_report_property_update_failure(self) -> None:
        with mock.patch.object(
            graphical_sessions,
            "_run",
            side_effect=[
                completed(json.dumps({"data": ["/org/freedesktop/Accounts/User1000"]})),
                completed(returncode=1),
            ],
        ):
            with self.assertRaisesRegex(
                RuntimeError, "failed to set SetSession for alice"
            ):
                graphical_sessions.set_default_sessions({"alice": "gnome"})

    def test_excludes_tty_sessions(self) -> None:
        sessions = [
            {"session": "1", "uid": 1000, "user": "alice", "class": "user"},
            {"session": "2", "uid": 1001, "user": "bob", "class": "user"},
        ]

        def run(*command: str) -> mock.Mock:
            if command[1] == "list-sessions":
                return completed(json.dumps(sessions))
            session_id = command[2]
            return completed("tty\n" if session_id == "1" else "wayland\n")

        with mock.patch.object(graphical_sessions, "_run", side_effect=run):
            self.assertEqual(
                graphical_sessions.list_graphical_sessions(),
                [("2", 1001, "bob")],
            )

    def test_locked_session_does_not_block_when_allowed(self) -> None:
        sessions = [("2", 1000, "alice")]
        output = io.StringIO()
        with (
            mock.patch.object(
                graphical_sessions, "list_graphical_sessions", return_value=sessions
            ),
            mock.patch.object(
                graphical_sessions, "session_is_locked", return_value=True
            ),
            contextlib.redirect_stderr(output),
        ):
            self.assertTrue(graphical_sessions.check_graphical_sessions(True))
        self.assertIn("Locked graphical sessions: alice (session 2)", output.getvalue())

    def test_unlocked_session_blocks(self) -> None:
        sessions = [("2", 1000, "alice")]
        output = io.StringIO()
        with (
            mock.patch.object(
                graphical_sessions, "list_graphical_sessions", return_value=sessions
            ),
            mock.patch.object(
                graphical_sessions, "session_is_locked", return_value=False
            ),
            contextlib.redirect_stderr(output),
        ):
            self.assertFalse(graphical_sessions.check_graphical_sessions(True))


if __name__ == "__main__":
    unittest.main()
