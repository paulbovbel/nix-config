"""Tests for local Actions pin updates."""

import importlib.util
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

SPEC = importlib.util.spec_from_file_location(
    "update_actions", Path(__file__).parents[1] / "scripts/update-actions.py"
)
updater = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(updater)


class UpdateActionsTests(unittest.TestCase):
    def resolve(self, version):
        refs = {
            "v5": "a" * 40,
            "v5.0.0": "b" * 40,
            "v5.2.0": "c" * 40,
            "v5.2.0^{}": "d" * 40,
            "v5.3.0-rc1": "e" * 40,
            "v6.0.0": "f" * 40,
        }
        output = "\n".join(f"{sha}\trefs/tags/{tag}" for tag, sha in refs.items())
        with patch.object(updater.subprocess, "run", return_value=Mock(stdout=output)):
            return updater.resolve("owner/repo/subdirectory", version)

    def test_major_channel(self):
        self.assertEqual(self.resolve("v5"), ("a" * 40, "v5"))

    def test_stable_release_and_annotated_tag(self):
        self.assertEqual(self.resolve("v5.0.0"), ("d" * 40, "v5.2.0"))

    def test_missing_channel(self):
        with self.assertRaises(ValueError):
            self.resolve("v7")

    def test_pin_pattern(self):
        line = f"        uses: owner/repo@{'a' * 40} # v5.0.0\n"
        match = updater.PIN.search(line)
        self.assertEqual(match["version"], "v5.0.0")
        self.assertIsNone(updater.PIN.search("uses: ./local-action"))


if __name__ == "__main__":
    unittest.main()
