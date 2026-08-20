#!/usr/bin/env python3
import json
import logging
import os
import subprocess
import sys
from pathlib import Path

import psutil


LOG_FILE = (
    Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    / "kitty"
    / "distrobox-split.log"
)
LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S%z",
)
logger = logging.getLogger(__name__)


def kitty_rc(*args: str) -> subprocess.CompletedProcess[str]:
    """Run a kitty remote-control command."""
    command = ["kitty", "@"]
    pass_fds = ()
    if listen_on := os.environ.get("KITTY_LISTEN_ON"):
        command += ["--to", listen_on]
        if listen_on.startswith("fd:"):
            pass_fds = (int(listen_on.removeprefix("fd:")),)
    command += args

    logger.info("running: %s ... %s", " ".join(command[:4]), " ".join(args))
    result = subprocess.run(command, text=True, capture_output=True, pass_fds=pass_fds)
    if result.returncode != 0:
        logger.error(
            "command failed status=%s stderr=%r",
            result.returncode,
            result.stderr.strip(),
        )
        result.check_returncode()
    return result


def podman_exec_env_value(argv: list[str], name: str) -> str | None:
    """Return an env var passed to `podman exec`, if present.

    Args:
        argv: Command-line argument list to inspect.
        name: Environment variable name to extract.

    Returns:
        The requested env var value when argv is a `podman exec` command that
        passes it with `--env`, otherwise None.
    """
    if not any(
        arg == "podman" and argv[index + 1 : index + 2] == ["exec"]
        for index, arg in enumerate(argv)
    ):
        return None

    prefix = f"{name}="

    for index, arg in enumerate(argv):
        env_value = None
        if arg == "--env" and index + 1 < len(argv):
            env_value = argv[index + 1]
        elif arg.startswith("--env="):
            env_value = arg.removeprefix("--env=")

        if env_value and env_value.startswith(prefix):
            return env_value.removeprefix(prefix)

    return None


def focused_podman_exec_container_id(windows: list[dict]) -> str | None:
    """Find the distrobox container used by focused Kitty window data.

    Kitty reports a distrobox shell as the host-side distrobox/podman launcher.
    The container name is carried by `podman exec --env CONTAINER_ID=...`.

    Returns:
        The CONTAINER_ID from a focused `podman exec` launcher, otherwise None.
    """
    for os_window in windows:
        for tab in os_window.get("tabs", []):
            for window in tab.get("windows", []):
                for process in window.get("foreground_processes", []):
                    if not (pid := process.get("pid")):
                        continue

                    try:
                        argv = psutil.Process(pid).cmdline()
                    except (
                        psutil.AccessDenied,
                        psutil.NoSuchProcess,
                        psutil.ZombieProcess,
                    ) as error:
                        logger.info("focused pid=%s cmdline unreadable: %s", pid, error)
                        continue

                    container_id = podman_exec_env_value(argv, "CONTAINER_ID")
                    logger.info(
                        "focused pid=%s podman_exec_container_id=%s",
                        pid,
                        container_id or "<empty>",
                    )
                    if container_id:
                        return container_id
    return None


def main() -> None:
    """Create a Kitty split, entering the focused distrobox when applicable."""
    if len(sys.argv) != 2:
        raise SystemExit("usage: kitty-distrobox-split <location>")

    location = sys.argv[1]
    logger.info(
        "start location=%s KITTY_LISTEN_ON=%s KITTY_WINDOW_ID=%s",
        location,
        os.environ.get("KITTY_LISTEN_ON", "<unset>"),
        os.environ.get("KITTY_WINDOW_ID", "<unset>"),
    )
    focused_windows = json.loads(kitty_rc("ls", "--match", "state:focused").stdout)
    container_id = focused_podman_exec_container_id(focused_windows)
    cwd = "last_reported" if container_id else "current"

    launch_args = [
        "launch",
        "--source-window",
        "state:focused",
        f"--location={location}",
        f"--cwd={cwd}",
    ]

    if container_id:
        logger.info("launching distrobox split container_id=%s", container_id)
        launch_args += [
            "bash",
            "-lc",
            '"$1" enter "$2"; exec "$0" -l',
            "bash",
            "distrobox",
            container_id,
        ]
    else:
        logger.info("launching normal split")

    kitty_rc(*launch_args)
    logger.info("launch complete")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        logger.exception("unhandled exception")
        raise
