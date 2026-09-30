import argparse
import contextlib
import fcntl
import json
import os
import socket
import subprocess
import sys
import tempfile
import uuid
from datetime import UTC, datetime
from pathlib import Path
from typing import Iterator
from urllib.parse import quote

UPGRADE_UNIT = "nixos-upgrade.service"
SYSTEM_PROFILE = Path("/nix/var/nix/profiles/system")
SYSTEM_COMPONENTS = ("initrd", "kernel", "kernel-modules")
CONFIGURATION_BRANCH_PATH = Path("/run/current-system/etc/nix-config/branch")


def run(
    *command: str,
    cwd: Path | None = None,
    input_text: str | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        capture_output=True,
        check=False,
        cwd=cwd,
        input=input_text,
        text=True,
    )


def command_output(*command: str, cwd: Path | None = None) -> str:
    result = run(*command, cwd=cwd)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"{' '.join(command)} failed: {detail}")
    return result.stdout.strip()


def run_streaming(*command: str, cwd: Path | None = None) -> None:
    result = subprocess.run(command, check=False, cwd=cwd)
    if result.returncode != 0:
        raise RuntimeError(
            f"{' '.join(command)} failed with exit code {result.returncode}"
        )


def get_current_revision() -> str:
    return command_output(
        "/run/current-system/sw/bin/nixos-version", "--configuration-revision"
    )


def get_current_branch(default_branch: str) -> str:
    try:
        branch = CONFIGURATION_BRANCH_PATH.read_text().strip()
    except OSError:
        branch = default_branch
    if not branch:
        raise RuntimeError("the active system does not record a configuration branch")
    command_output("git", "check-ref-format", "--branch", branch)
    return branch


def remote_branch_exists(repository: str, branch: str) -> bool:
    result = run(
        "git",
        "ls-remote",
        "--exit-code",
        "--heads",
        repository,
        f"refs/heads/{branch}",
    )
    if result.returncode == 0:
        return True
    if result.returncode == 2:
        return False
    detail = result.stderr.strip() or result.stdout.strip()
    raise RuntimeError(f"failed to inspect remote branch {branch}: {detail}")


def resolve_upgrade_branch(repository: str, default_branch: str) -> tuple[str, bool]:
    branch = get_current_branch(default_branch)
    if branch != default_branch and not remote_branch_exists(repository, branch):
        print(
            f"configured branch {branch} was deleted; switching to {default_branch}",
            flush=True,
        )
        return default_branch, True
    return branch, False


def check_revision(
    repository: str, branch: str, allow_branch_transition: bool = False
) -> str:
    current = get_current_revision()
    if not current or current == "unknown":
        raise RuntimeError("the active system does not record a configuration revision")
    if current == "dirty" or current.endswith("-dirty"):
        raise RuntimeError(
            f"the active system was built from dirty revision {current}; "
            "refusing a possible rollback"
        )

    with tempfile.TemporaryDirectory(prefix="auto-upgrade-") as temp_dir:
        checkout = Path(temp_dir)
        command_output("git", "init", "--quiet", cwd=checkout)
        command_output(
            "git",
            "fetch",
            "--quiet",
            "--no-tags",
            repository,
            f"refs/heads/{branch}",
            cwd=checkout,
        )
        candidate = command_output("git", "rev-parse", "FETCH_HEAD", cwd=checkout)
        if allow_branch_transition:
            print(
                f"accepting {branch} at {candidate} after configured branch deletion",
                flush=True,
            )
            return candidate
        current_exists = run(
            "git", "cat-file", "-e", f"{current}^{{commit}}", cwd=checkout
        )
        if current_exists.returncode != 0:
            fetch_current = run(
                "git",
                "fetch",
                "--quiet",
                "--no-tags",
                repository,
                current,
                cwd=checkout,
            )
            if fetch_current.returncode != 0:
                raise RuntimeError(
                    f"active revision {current} is not available from {repository}; "
                    "refusing a possible rollback"
                )
        ancestor = run(
            "git", "merge-base", "--is-ancestor", current, candidate, cwd=checkout
        )
        if ancestor.returncode == 1:
            raise RuntimeError(
                f"remote {branch} at {candidate} does not descend from the active "
                f"revision {current}; refusing a possible rollback"
            )
        if ancestor.returncode != 0:
            detail = ancestor.stderr.strip() or ancestor.stdout.strip()
            raise RuntimeError(f"failed to compare configuration revisions: {detail}")

    print(f"revision check passed: {current} -> {candidate}", flush=True)
    return candidate


def check_graphical_sessions() -> None:
    result = run("graphical-sessions", "check", "--allow-locked")
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        raise RuntimeError("unlocked graphical sessions prevent activation")


def system_components(path: Path) -> tuple[str, ...]:
    return tuple(os.path.realpath(path / component) for component in SYSTEM_COMPONENTS)


def in_reboot_window(lower: str, upper: str, current: str | None = None) -> bool:
    current = current or datetime.now().strftime("%H:%M")
    if lower < upper:
        return lower < current < upper
    return current < upper or current > lower


def write_outcome(path: Path, status: str, reason: str) -> None:
    path.write_text(json.dumps({"status": status, "reason": reason}))


def run_upgrade(
    target: str,
    repository: str,
    default_branch: str,
    working_directory: Path,
    outcome_path: Path,
    reboot_window_lower: str,
    reboot_window_upper: str,
) -> None:
    outcome_path.unlink(missing_ok=True)
    branch, allow_branch_transition = resolve_upgrade_branch(repository, default_branch)
    print(f"Configuration branch: {branch}", flush=True)
    candidate = check_revision(repository, branch, allow_branch_transition)
    check_graphical_sessions()

    result_path = working_directory / "result"
    result_path.unlink(missing_ok=True)
    encoded_branch = quote(branch, safe="")
    pinned_flake = f"git+{repository}?ref={encoded_branch}&rev={candidate}"
    build_target = (
        f"{pinned_flake}#nixosConfigurations.{target}.config.system.build.toplevel"
    )
    os.environ["NIX_CONFIG_BRANCH"] = branch
    run_streaming(
        "nix",
        "build",
        "--impure",
        "--refresh",
        "--out-link",
        str(result_path),
        build_target,
        cwd=working_directory,
    )

    # This is the final gate before changing the system profile or activating anything.
    check_graphical_sessions()
    built_system = result_path.resolve()
    reboot_required = system_components(
        Path("/run/booted-system")
    ) != system_components(built_system)
    print(f"Reboot required: {'yes' if reboot_required else 'no'}", flush=True)

    if reboot_required and not in_reboot_window(
        reboot_window_lower, reboot_window_upper
    ):
        reason = "reboot required outside the configured reboot window"
        write_outcome(outcome_path, "deferred", reason)
        print(reason, flush=True)
        return

    run_streaming(
        "nix-env",
        "--profile",
        str(SYSTEM_PROFILE),
        "--set",
        str(built_system),
    )
    activation = str(built_system / "bin/switch-to-configuration")
    if reboot_required:
        run_streaming(activation, "boot")
        write_outcome(outcome_path, "succeeded", "reboot scheduled")
        run_streaming("shutdown", "-r", "+1")
    else:
        run_streaming(activation, "switch")
        write_outcome(outcome_path, "succeeded", "configuration activated")


def get_upgrade_journal() -> str:
    invocation_id = os.environ.get("INVOCATION_ID", "")
    if invocation_id:
        result = run(
            "journalctl",
            f"_SYSTEMD_INVOCATION_ID={invocation_id}",
            "--lines=500",
            "--no-pager",
        )
    else:
        result = run(
            "journalctl",
            "--unit",
            UPGRADE_UNIT,
            "--boot",
            "--lines=500",
            "--no-pager",
        )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"failed to read upgrade journal: {detail}")
    return result.stdout.strip()


def send_mail(subject: str, recipient: str, body: str) -> bool:
    result = run("mail", "-s", subject, recipient, input_text=body)
    if result.returncode == 0:
        return True
    detail = result.stderr.strip() or result.stdout.strip()
    print(f"failed to send upgrade report: {detail}", file=sys.stderr)
    return False


@contextlib.contextmanager
def lock_outbox(outbox: Path) -> Iterator[None]:
    outbox.mkdir(parents=True, exist_ok=True)
    with (outbox / ".lock").open("a+") as lock_file:
        fcntl.flock(lock_file, fcntl.LOCK_EX)
        yield


def queue_report(recipient: str, outbox: Path, outcome_path: Path) -> None:
    hostname = socket.gethostname()
    service_result = os.environ.get("SERVICE_RESULT", "unknown")
    outcome: dict[str, str] = {}
    try:
        outcome = json.loads(outcome_path.read_text())
    except (json.JSONDecodeError, OSError, TypeError):
        pass
    status = outcome.get("status", "succeeded")
    if service_result != "success":
        status = "failed"
    reason = outcome.get("reason", "none recorded")
    subject = f"[{hostname}] NixOS auto-upgrade {status}"
    try:
        journal = get_upgrade_journal()
    except RuntimeError as error:
        journal = str(error)
    body = "\n".join(
        [
            f"Host: {hostname}",
            f"Status: {status}",
            f"Reason: {reason}",
            f"Service result: {service_result}",
            f"Exit code: {os.environ.get('EXIT_CODE', 'unknown')}",
            f"Exit status: {os.environ.get('EXIT_STATUS', 'unknown')}",
            f"Time: {datetime.now(UTC).isoformat()}",
            "",
            journal,
            "",
        ]
    )

    with lock_outbox(outbox):
        report_path = (
            outbox
            / f"{datetime.now(UTC).strftime('%Y%m%dT%H%M%S')}-{uuid.uuid4()}.json"
        )
        with tempfile.NamedTemporaryFile(
            "w", dir=outbox, delete=False, encoding="utf-8"
        ) as report_file:
            json.dump(
                {"subject": subject, "recipient": recipient, "body": body},
                report_file,
            )
            temporary_path = Path(report_file.name)
        temporary_path.replace(report_path)

        if send_mail(subject, recipient, body):
            report_path.unlink()
        else:
            print(f"queued upgrade report for retry: {report_path}", file=sys.stderr)


def retry_reports(outbox: Path) -> None:
    if not outbox.exists():
        return
    with lock_outbox(outbox):
        for report_path in sorted(outbox.glob("*.json")):
            try:
                report = json.loads(report_path.read_text())
                sent = send_mail(report["subject"], report["recipient"], report["body"])
            except (json.JSONDecodeError, KeyError, OSError, TypeError) as error:
                print(f"invalid queued report {report_path}: {error}", file=sys.stderr)
                continue
            if sent:
                report_path.unlink()
                print(f"sent queued upgrade report: {report_path}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Guard and report NixOS upgrades")
    actions = parser.add_subparsers(dest="action", required=True)

    run_parser = actions.add_parser("run")
    run_parser.add_argument("--target", required=True)
    run_parser.add_argument("--repository", required=True)
    run_parser.add_argument("--branch", required=True)
    run_parser.add_argument("--working-directory", type=Path, required=True)
    run_parser.add_argument("--outcome", type=Path, required=True)
    run_parser.add_argument("--reboot-window-lower", required=True)
    run_parser.add_argument("--reboot-window-upper", required=True)

    report_parser = actions.add_parser("report")
    report_parser.add_argument("--recipient", required=True)
    report_parser.add_argument("--outbox", type=Path, required=True)
    report_parser.add_argument("--outcome", type=Path, required=True)

    retry_parser = actions.add_parser("retry-reports")
    retry_parser.add_argument("--outbox", type=Path, required=True)
    args = parser.parse_args()

    try:
        if args.action == "run":
            run_upgrade(
                args.target,
                args.repository,
                args.branch,
                args.working_directory,
                args.outcome,
                args.reboot_window_lower,
                args.reboot_window_upper,
            )
        elif args.action == "report":
            queue_report(args.recipient, args.outbox, args.outcome)
        else:
            retry_reports(args.outbox)
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
