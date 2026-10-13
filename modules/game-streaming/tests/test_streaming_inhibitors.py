import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"


class StreamingInhibitorTests(unittest.TestCase):
    def probe(self, script, events, *, steam=True, sunshine=True):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "Steam" / "logs" / "streaming_log.txt"
            log.parent.mkdir(parents=True)
            log.write_text(events)
            environment = root / "environment.sh"
            environment.write_text(
                """
pgrep() { return "$STEAM_STATUS"; }
ps() { printf '%s\n' 'Mon Oct 12 12:00:00 2026'; }
systemctl() {
  if [[ "$2" == is-active ]]; then
    return "$SUNSHINE_STATUS"
  fi
  printf '%s\n' current-invocation
}
journalctl() {
  [[ " $* " == *' --invocation=current-invocation '* ]] || exit 99
  printf '%s\n' "$STREAM_EVENTS"
}
sleep() { exit 42; }
"""
            )
            result = subprocess.run(
                ["bash", str(SCRIPTS / script), "--wait"],
                env={
                    **os.environ,
                    "HOME": directory,
                    "XDG_DATA_HOME": directory,
                    "BASH_ENV": str(environment),
                    "STEAM_STATUS": "0" if steam else "1",
                    "SUNSHINE_STATUS": "0" if sunshine else "1",
                    "STREAM_EVENTS": events,
                },
                capture_output=True,
                text=True,
                timeout=5,
            )
            self.assertIn(result.returncode, (0, 42), result.stderr)
            return result.returncode == 42

    def steam(self, events, **kwargs):
        return self.probe("inhibit-sleep-while-steam-remote-play.sh", events, **kwargs)

    def sunshine(self, events, **kwargs):
        return self.probe("inhibit-sleep-while-sunshine.sh", events, **kwargs)

    def test_steam_active_stream_and_disconnect(self):
        events = "[2026-10-12 12:01:00][60.0] Streaming started to steamdeck\n"
        self.assertTrue(self.steam(events))
        self.assertFalse(
            self.steam(events + "[2026-10-12 12:02:00] >>> Stopped desktop stream\n")
        )

    def test_steam_crash_releases_inhibitor(self):
        self.assertFalse(
            self.steam(
                "[2026-10-12 12:01:00] Streaming started to steamdeck\n", steam=False
            )
        )

    def test_previous_steam_run_does_not_inhibit(self):
        self.assertFalse(
            self.steam("[2026-10-12 11:00:00] Streaming started to steamdeck\n")
        )

    def test_game_recording_does_not_inhibit(self):
        self.assertFalse(
            self.steam("[2026-10-12 12:01:00] Starting new game recording session\n")
        )

    def test_sunshine_keeps_inhibitor_until_last_client_disconnects(self):
        events = "Info: CLIENT CONNECTED\nInfo: CLIENT CONNECTED\n"
        events += "Info: CLIENT DISCONNECTED\n"
        self.assertTrue(self.sunshine(events))
        self.assertFalse(self.sunshine(events + "Info: CLIENT DISCONNECTED\n"))

    def test_idle_sunshine_does_not_inhibit(self):
        self.assertFalse(self.sunshine("Info: Server started\n"))

    def test_sunshine_crash_releases_inhibitor(self):
        self.assertFalse(self.sunshine("Info: CLIENT CONNECTED\n", sunshine=False))


if __name__ == "__main__":
    unittest.main()
