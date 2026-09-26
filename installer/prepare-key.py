#!/usr/bin/env python3

import argparse
import re
import shutil
import socket
import subprocess
import tempfile
from pathlib import Path


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Prepare the selected host identity for an offline installer."
    )
    parser.add_argument("host")
    parser.add_argument("mode", choices=("reuse", "new"))
    args = parser.parse_args()

    if args.mode == "reuse" and args.host != socket.gethostname():
        raise SystemExit(
            "reuse mode requires the selected host to match the running hostname"
        )

    repo = Path(__file__).resolve().parent.parent
    host_path = repo / "hosts" / args.host / "default.nix"
    payload_dir = repo / "secrets" / "installer"
    payload_path = payload_dir / f"{args.host}-host.agekey.age"
    unlock_path = payload_dir / f"{args.host}-installer.agekey.age"
    recipient_path = payload_dir / f"{args.host}-installer-recipient"

    contents = host_path.read_text()
    pattern = re.compile(r'^(  ageRecipient = ")(age1[^";]+)(";)$', re.M)
    match = pattern.search(contents)
    if match is None:
        raise SystemExit(f"could not find ageRecipient in {host_path}")
    expected_recipient = match.group(2)

    with tempfile.TemporaryDirectory(prefix=f"{args.host}-identity-") as tmp:
        identity = Path(tmp) / "host.agekey"
        encrypted_payload = Path(tmp) / "host.agekey.age"
        installer_identity = Path(tmp) / "installer.agekey"
        encrypted_installer_identity = Path(tmp) / "installer.agekey.age"

        if args.mode == "new":
            confirmation = input(
                f"Type ROTATE {args.host} to generate a new identity and rekey secrets: "
            )
            if confirmation != f"ROTATE {args.host}":
                raise SystemExit("identity rotation cancelled")
            run("age-keygen", "-o", str(identity))
        else:
            identity.write_bytes(
                subprocess.run(
                    ["sudo", "cat", "/persist/etc/agenix/host.agekey"],
                    check=True,
                    capture_output=True,
                ).stdout
            )
            identity.chmod(0o600)

        recipient = subprocess.run(
            ["age-keygen", "-y", str(identity)],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        if args.mode == "reuse" and recipient != expected_recipient:
            raise SystemExit(
                f"identity recipient mismatch: expected {expected_recipient}, got {recipient}"
            )

        run("age-keygen", "-o", str(installer_identity))
        installer_recipient = subprocess.run(
            ["age-keygen", "-y", str(installer_identity)],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        run(
            "age",
            "--recipient",
            installer_recipient,
            "--output",
            str(encrypted_payload),
            str(identity),
        )
        print("Encrypt the installer payloads with a strong, unique passphrase.")
        run(
            "age",
            "--passphrase",
            "--output",
            str(encrypted_installer_identity),
            str(installer_identity),
        )

        if args.mode == "new":
            updated = pattern.sub(rf"\g<1>{recipient}\g<3>", contents)
            host_path.write_text(updated)
            try:
                run("agenix", "-r")
            except subprocess.CalledProcessError:
                host_path.write_text(contents)
                raise

        payload_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(
            prefix=".prepare-key-", dir=payload_dir
        ) as staging:
            staged = Path(staging)
            for source, destination in (
                (encrypted_payload, payload_path),
                (encrypted_installer_identity, unlock_path),
            ):
                staged_payload = staged / destination.name
                shutil.copy2(source, staged_payload)
                staged_payload.replace(destination)
            staged_recipient = staged / recipient_path.name
            staged_recipient.write_text(f"{installer_recipient}\n")
            staged_recipient.replace(recipient_path)

    if args.mode == "new":
        print(f"Generated a new identity and prepared {payload_path}")
        print(
            f"Review and commit {host_path.relative_to(repo)} plus the rekeyed secrets before installation."
        )
    else:
        print(f"Prepared {payload_path} with the existing {args.host} identity")


if __name__ == "__main__":
    main()
