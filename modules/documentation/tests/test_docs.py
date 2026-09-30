import tempfile
import unittest
from pathlib import Path

from build_search import build_index
from check_links import check_site
from split_options import split_options
from transform_markdown import transform_markdown


class TransformMarkdownTests(unittest.TestCase):
    def test_shifts_headings_without_changing_fenced_code(self) -> None:
        source = ["# Title\n", "## Section\n", "```nix\n", "## comment\n", "```\n"]
        self.assertEqual(
            list(transform_markdown(source, drop_title=True)),
            ["### Section\n", "```nix\n", "## comment\n", "```\n"],
        )


class SplitOptionsTests(unittest.TestCase):
    def test_groups_options_by_declaration_directory(self) -> None:
        options = {
            "example.enable": {
                "declarations": [{"name": "modules/example/options.nix"}]
            },
            "other.enable": {"declarations": [{"name": "modules/other"}]},
        }
        self.assertEqual(
            split_options(options, ["example", "other"]),
            {
                "example": {"example.enable": options["example.enable"]},
                "other": {"other.enable": options["other.enable"]},
            },
        )


class CheckLinksTests(unittest.TestCase):
    def test_reports_missing_assets_and_anchors(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            site = Path(directory)
            (site / "index.html").write_text(
                '<a href="other.html#missing">Other</a><script src="site.js"></script>',
                encoding="utf-8",
            )
            (site / "other.html").write_text(
                '<h1 id="present">Other</h1>', encoding="utf-8"
            )
            self.assertEqual(
                check_site(site),
                [
                    "index.html: missing anchor other.html#missing",
                    "index.html: missing target site.js",
                ],
            )


class BuildSearchTests(unittest.TestCase):
    def test_indexes_modules_and_only_option_headings(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            site = Path(directory)
            (site / "example.html").write_text(
                """
                <h1 id="example">Example</h1>
                <h2 id="introduction">Introduction</h2>
                <h3 id="requirements">Requirements</h3>
                <h2 id="options">Options</h2>
                <h3 id="exampleenable"><code>example.enable</code></h3>
                """,
                encoding="utf-8",
            )
            self.assertEqual(
                build_index(site, ["example"]),
                [
                    {
                        "kind": "module",
                        "label": "Example",
                        "url": "example.html#example",
                    },
                    {
                        "kind": "option",
                        "label": "example.enable",
                        "url": "example.html#exampleenable",
                    },
                ],
            )


if __name__ == "__main__":
    unittest.main()
