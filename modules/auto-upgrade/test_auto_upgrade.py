import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import auto_upgrade


def git(repository: Path, *arguments: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repository), *arguments],
        capture_output=True,
        check=True,
        text=True,
    )
    return result.stdout.strip()


def commit(repository: Path, message: str) -> str:
    (repository / "value").write_text(message)
    git(repository, "add", "value")
    git(repository, "commit", "--quiet", "-m", message)
    return git(repository, "rev-parse", "HEAD")


class RevisionGuardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.repository = Path(self.temp_dir.name)
        git(self.repository, "init", "--quiet", "--initial-branch=main")
        git(self.repository, "config", "user.email", "test@example.com")
        git(self.repository, "config", "user.name", "Test User")

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_rejects_dirty_revision(self) -> None:
        with mock.patch.object(
            auto_upgrade, "get_current_revision", return_value="abc-dirty"
        ):
            with self.assertRaisesRegex(RuntimeError, "dirty revision"):
                auto_upgrade.check_revision(str(self.repository), "main")

    def test_accepts_fast_forward(self) -> None:
        current = commit(self.repository, "current")
        candidate = commit(self.repository, "candidate")
        with mock.patch.object(
            auto_upgrade, "get_current_revision", return_value=current
        ):
            self.assertEqual(
                auto_upgrade.check_revision(str(self.repository), "main"), candidate
            )

    def test_rejects_diverged_branch(self) -> None:
        base = commit(self.repository, "base")
        git(self.repository, "switch", "--quiet", "-c", "deployed")
        current = commit(self.repository, "deployed")
        git(self.repository, "switch", "--quiet", "main")
        commit(self.repository, "candidate")
        self.assertNotEqual(base, current)

        with mock.patch.object(
            auto_upgrade, "get_current_revision", return_value=current
        ):
            with self.assertRaisesRegex(RuntimeError, "does not descend"):
                auto_upgrade.check_revision(str(self.repository), "main")

    def test_allows_transition_after_branch_deletion(self) -> None:
        candidate = commit(self.repository, "candidate")
        with mock.patch.object(
            auto_upgrade,
            "get_current_revision",
            return_value="0123456789012345678901234567890123456789",
        ):
            self.assertEqual(
                auto_upgrade.check_revision(
                    str(self.repository), "main", allow_branch_transition=True
                ),
                candidate,
            )


class UpgradeWorkflowTest(unittest.TestCase):
    def test_deleted_feature_branch_falls_back_to_main(self) -> None:
        with (
            mock.patch.object(
                auto_upgrade,
                "get_current_branch",
                return_value="feature/session-upgrade",
            ),
            mock.patch.object(auto_upgrade, "remote_branch_exists", return_value=False),
        ):
            self.assertEqual(
                auto_upgrade.resolve_upgrade_branch("/repo", "main"),
                ("main", True),
            )

    def test_rechecks_sessions_after_build_before_activation(self) -> None:
        events: list[str] = []
        commands: list[tuple[str, ...]] = []

        def check_sessions() -> None:
            events.append("check-sessions")

        def run_streaming(*command: str, cwd: Path | None = None) -> None:
            del cwd
            commands.append(command)
            executable = Path(command[0]).name
            events.append(
                "switch" if executable == "switch-to-configuration" else executable
            )

        with (
            tempfile.TemporaryDirectory() as temp_dir,
            mock.patch.dict(os.environ),
            mock.patch.object(
                auto_upgrade,
                "resolve_upgrade_branch",
                return_value=("feature/session-upgrade", False),
            ),
            mock.patch.object(
                auto_upgrade, "check_revision", return_value="candidate-revision"
            ) as revision_check,
            mock.patch.object(
                auto_upgrade,
                "check_graphical_sessions",
                side_effect=check_sessions,
            ),
            mock.patch.object(
                auto_upgrade,
                "run_streaming",
                side_effect=run_streaming,
            ),
            mock.patch.object(
                auto_upgrade,
                "system_components",
                return_value=("initrd", "kernel", "modules"),
            ),
        ):
            auto_upgrade.run_upgrade(
                "media",
                "/repo",
                "main",
                Path(temp_dir),
                Path(temp_dir) / "outcome.json",
                "03:00",
                "05:00",
            )

        self.assertEqual(
            events,
            ["check-sessions", "nix", "check-sessions", "nix-env", "switch"],
        )
        revision_check.assert_called_once_with(
            "/repo", "feature/session-upgrade", False
        )
        self.assertIn("ref=feature%2Fsession-upgrade", commands[0][-1])
        self.assertIn("rev=candidate-revision", commands[0][-1])

    def test_reboot_outside_window_is_deferred(self) -> None:
        commands: list[tuple[str, ...]] = []

        with (
            tempfile.TemporaryDirectory() as temp_dir,
            mock.patch.object(
                auto_upgrade, "resolve_upgrade_branch", return_value=("main", False)
            ),
            mock.patch.object(
                auto_upgrade, "check_revision", return_value="candidate-revision"
            ),
            mock.patch.object(auto_upgrade, "check_graphical_sessions"),
            mock.patch.object(
                auto_upgrade,
                "run_streaming",
                side_effect=lambda *command, **_kwargs: commands.append(command),
            ),
            mock.patch.object(
                auto_upgrade,
                "system_components",
                side_effect=[("booted",), ("built",)],
            ),
            mock.patch.object(auto_upgrade, "in_reboot_window", return_value=False),
        ):
            outcome = Path(temp_dir) / "outcome.json"
            auto_upgrade.run_upgrade(
                "media",
                "/repo",
                "main",
                Path(temp_dir),
                outcome,
                "03:00",
                "05:00",
            )

            self.assertEqual(json.loads(outcome.read_text())["status"], "deferred")
        self.assertEqual([Path(command[0]).name for command in commands], ["nix"])


class ReportQueueTest(unittest.TestCase):
    def test_failed_delivery_is_persisted_and_retried(self) -> None:
        with (
            tempfile.TemporaryDirectory() as temp_dir,
            mock.patch.object(auto_upgrade, "get_upgrade_journal", return_value="log"),
            mock.patch.object(auto_upgrade, "send_mail", return_value=False),
        ):
            root = Path(temp_dir)
            outbox = root / "outbox"
            outcome = root / "outcome.json"
            auto_upgrade.write_outcome(outcome, "deferred", "waiting for reboot window")
            auto_upgrade.queue_report("test@example.com", outbox, outcome)
            self.assertEqual(len(list(outbox.glob("*.json"))), 1)

            with mock.patch.object(auto_upgrade, "send_mail", return_value=True):
                auto_upgrade.retry_reports(outbox)
            self.assertEqual(list(outbox.glob("*.json")), [])


if __name__ == "__main__":
    unittest.main()
