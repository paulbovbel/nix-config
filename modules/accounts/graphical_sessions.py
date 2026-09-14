import argparse
import json
import subprocess
import sys
import time

type GraphicalSession = tuple[str, int, str]
GRAPHICAL_SESSION_TYPES = {"mir", "wayland", "x11"}


def _positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def _run(*command: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        capture_output=True,
        check=False,
        text=True,
    )


def session_property(session_id: str, property_name: str) -> str:
    result = _run(
        "loginctl",
        "show-session",
        session_id,
        f"--property={property_name}",
        "--value",
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"failed to inspect session {session_id}: {detail}")
    return result.stdout.strip()


def list_graphical_sessions() -> list[GraphicalSession]:
    result = _run("loginctl", "list-sessions", "--json=short")
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"failed to list sessions: {detail}")

    try:
        raw_sessions = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(
            f"failed to parse sessions json: {result.stdout.strip()!r}"
        ) from error
    if not isinstance(raw_sessions, list):
        raise RuntimeError(f"unexpected sessions json: {raw_sessions!r}")

    sessions: list[GraphicalSession] = []
    for entry in raw_sessions:
        if not isinstance(entry, dict):
            continue
        session_id = entry.get("session")
        uid_raw = entry.get("uid")
        user_name = entry.get("user")
        if not session_id or uid_raw is None or not user_name:
            continue
        if entry.get("class") != "user":
            continue
        session_id = str(session_id)
        if session_property(session_id, "Type") not in GRAPHICAL_SESSION_TYPES:
            continue
        try:
            uid = int(uid_raw)
        except (TypeError, ValueError):
            continue
        sessions.append((session_id, uid, str(user_name)))
    return sessions


def session_is_locked(session_id: str) -> bool:
    locked = session_property(session_id, "LockedHint")
    if locked not in {"yes", "no"}:
        raise RuntimeError(
            f"unexpected lock state for session {session_id}: {locked!r}"
        )
    return locked == "yes"


def send_logout_warning(user_name: str, uid: int, warning_seconds: int) -> bool:
    result = _run(
        "sudo",
        "-n",
        "-u",
        user_name,
        "env",
        f"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{uid}/bus",
        "gdbus",
        "call",
        "--session",
        "--dest",
        "org.gnome.Shell",
        "--object-path",
        "/org/freedesktop/Notifications",
        "--method",
        "org.freedesktop.Notifications.Notify",
        "logout-warning",
        "0",
        "dialog-warning",
        "Logout pending",
        f"You will be logged out in {warning_seconds} seconds.",
        "[]",
        "{}",
        str(warning_seconds * 1000),
    )
    if result.returncode == 0:
        return True
    detail = result.stderr.strip() or result.stdout.strip()
    print(
        f"failed to send logout warning to {user_name} (uid={uid}): {detail}",
        file=sys.stderr,
    )
    return False


def logout_graphical_sessions(warning_seconds: int) -> None:
    sessions = list_graphical_sessions()
    users = {(user_name, uid) for _session_id, uid, user_name in sessions}
    warned = {
        (user_name, uid)
        for user_name, uid in users
        if send_logout_warning(user_name, uid, warning_seconds)
    }

    if sessions:
        if not warned:
            print(
                "no logout warnings were delivered before terminating sessions",
                file=sys.stderr,
            )
        time.sleep(warning_seconds)

    for session_id, _uid, _user_name in sessions:
        print(f"terminating graphical session {session_id}", file=sys.stderr)
        result = _run("loginctl", "terminate-session", session_id)
        if result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip()
            print(
                f"failed to terminate session {session_id}: {detail}", file=sys.stderr
            )


def wait_for_no_graphical_sessions(poll_seconds: int, allow_locked: bool) -> None:
    while True:
        sessions = list_graphical_sessions()
        if allow_locked:
            sessions = [
                session for session in sessions if not session_is_locked(session[0])
            ]
        if not sessions:
            return
        print(
            f"graphical sessions are active; retrying in {poll_seconds} seconds",
            file=sys.stderr,
        )
        time.sleep(poll_seconds)


def check_graphical_sessions(allow_locked: bool) -> bool:
    sessions = list_graphical_sessions()
    locked_sessions = [session for session in sessions if session_is_locked(session[0])]
    unlocked_sessions = [
        session for session in sessions if session not in locked_sessions
    ]

    locked_details = ", ".join(
        f"{user_name} (session {session_id})"
        for session_id, _uid, user_name in locked_sessions
    )
    print(
        f"Locked graphical sessions: {locked_details or 'none'}",
        file=sys.stderr,
    )

    blocking_sessions = unlocked_sessions if allow_locked else sessions
    if not blocking_sessions:
        return True
    blocking_details = ", ".join(
        f"{user_name} (session {session_id})"
        for session_id, _uid, user_name in blocking_sessions
    )
    print(
        f"graphical sessions prevent upgrade: {blocking_details}",
        file=sys.stderr,
    )
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Manage active graphical sessions")
    actions = parser.add_subparsers(dest="action", required=True)
    logout_parser = actions.add_parser("logout", help="log out graphical sessions")
    logout_parser.add_argument("--warning-seconds", type=_positive_int, default=60)
    check_parser = actions.add_parser("check", help="check for graphical sessions")
    check_parser.add_argument(
        "--allow-locked",
        action="store_true",
        help="ignore locked graphical sessions",
    )
    wait_parser = actions.add_parser("wait", help="wait for graphical sessions to end")
    wait_parser.add_argument("--poll-seconds", type=_positive_int, default=300)
    wait_parser.add_argument(
        "--allow-locked",
        action="store_true",
        help="do not wait for locked graphical sessions",
    )
    args = parser.parse_args()

    try:
        if args.action == "logout":
            logout_graphical_sessions(args.warning_seconds)
        elif args.action == "check":
            return 0 if check_graphical_sessions(args.allow_locked) else 1
        else:
            wait_for_no_graphical_sessions(args.poll_seconds, args.allow_locked)
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
