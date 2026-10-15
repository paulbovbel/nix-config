import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class DeploymentCommands(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        source = Path(__file__).resolve().parents[1]
        self.module = self.root / "modules/deployment"
        shutil.copytree(source / "scripts", self.module / "scripts")
        host = self.root / "hosts/test"
        host.mkdir(parents=True)
        (host / "default.nix").write_text('  ageRecipient = "age1test";\n')
        payloads = self.root / "secrets/installer"
        payloads.mkdir(parents=True)
        for name in ("test-host.agekey.age", "test-installer.agekey.age"):
            (payloads / name).write_text("encrypted fixture")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        mock = self.bin / "mock"
        mock.write_text(
            f"#!{sys.executable}\n" + (source / "tests/mock_command.py").read_text()
        )
        mock.chmod(0o755)
        for name in (
            "git",
            "hostname",
            "nix",
            "nixos-rebuild",
            "age",
            "age-keygen",
            "ssh",
            "nixos-anywhere",
        ):
            (self.bin / name).symlink_to(mock)
        self.log = self.root / "commands.jsonl"
        self.env = dict(
            os.environ,
            PATH=f"{self.bin}:{os.environ['PATH']}",
            COMMAND_LOG=str(self.log),
        )

    def run_script(self, script, *args, input="", **env):
        return subprocess.run(
            ["bash", str(self.module / "scripts" / script), *args],
            env=self.env | env,
            input=input,
            text=True,
            capture_output=True,
        )

    def commands(self, name):
        return [
            entry
            for line in self.log.read_text().splitlines()
            if (entry := json.loads(line))["command"] == name
        ]

    def test_remote_override_and_argument_boundaries(self):
        result = self.run_script(
            "remote/activate.sh",
            "switch",
            "test",
            "--target",
            "root@address",
            "--build-host",
            "localhost",
            "--option",
            "name",
            "two words",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        (call,) = self.commands("nixos-rebuild")
        self.assertIn("root@address", call["args"])
        self.assertNotIn("--build-host", call["args"])
        self.assertEqual(call["args"][-3:], ["--option", "name", "two words"])
        self.assertEqual(call["branch"], "feature/deploy")

    def test_build_plan_records_dirty_source(self):
        result = self.run_script(
            "remote/activate.sh", "build-plan", "test", TEST_DIRTY="1"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        (call,) = [call for call in self.commands("nix") if call["args"][0] == "build"]
        self.assertIn("--dry-run", call["args"])
        self.assertIn(str(self.root / "result-test"), call["args"])
        self.assertEqual(call["revision"], "abc123-dirty")

    def test_detached_head_stops_before_nix(self):
        result = self.run_script("remote/activate.sh", "switch", "test", TEST_BRANCH="")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands("nix"), [])

    def test_iso_build_reuses_payloads_and_records_current_source(self):
        archive = self.root / "state with spaces.age"
        archive.write_text("encrypted archive")
        payload = self.root / "secrets/installer/test-host.agekey.age"
        for _ in range(2):
            result = self.run_script(
                "usb/build-iso.sh",
                "test",
                "--state",
                str(archive),
                "--option",
                "name",
                "two words",
                TEST_DIRTY="1",
            )
            self.assertEqual(result.returncode, 0, result.stderr)
        builds = [call for call in self.commands("nix") if call["args"][0] == "build"]
        self.assertEqual(len(builds), 2)
        for call in builds:
            self.assertIn(str(self.root / "result-installer-test"), call["args"])
            self.assertEqual(call["revision"], "abc123-dirty")
            self.assertEqual(call["args"][-3:], ["--option", "name", "two words"])
        self.assertEqual(payload.read_text(), "encrypted fixture")
        self.assertEqual(self.commands("age"), [])
        self.assertEqual(self.commands("age-keygen"), [])

    def test_missing_payload_stops_iso_before_build(self):
        (self.root / "secrets/installer/test-host.agekey.age").unlink()
        result = self.run_script("usb/build-iso.sh", "test")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands("nix"), [])

    def test_install_cleans_identity_on_success_and_failure(self):
        for exit_code in ("0", "1"):
            with self.subTest(exit_code=exit_code):
                result = self.run_script(
                    "remote/install.sh",
                    "test",
                    "root@address",
                    input="ERASE test\n",
                    TEST_INSTALL_EXIT=exit_code,
                )
                self.assertEqual(result.returncode, int(exit_code), result.stderr)
                call = self.commands("nixos-anywhere")[-1]
                args = call["args"]
                extra = Path(args[args.index("--extra-files") + 1])
                self.assertFalse(extra.exists())
                self.assertIn("https://cache.example", args)
                self.assertIn("pure-eval", args)
                self.assertEqual(call["branch"], "feature/deploy")

    def test_wrong_recipient_stops_before_remote_changes(self):
        result = self.run_script(
            "remote/install.sh",
            "test",
            "root@address",
            input="ERASE test\n",
            TEST_RECIPIENT="age1wrong",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands("nixos-anywhere"), [])
        self.assertEqual(len(self.commands("ssh")), 1)

    def test_cancel_stops_before_remote_changes(self):
        result = self.run_script(
            "remote/install.sh", "test", "root@address", input="no\n"
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands("nixos-anywhere"), [])
        self.assertEqual(len(self.commands("ssh")), 1)


if __name__ == "__main__":
    unittest.main()
