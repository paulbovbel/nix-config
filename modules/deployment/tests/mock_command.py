"""External command stand-in for deployment orchestration tests."""

import json
import os
from pathlib import Path
import sys

command = Path(sys.argv[0]).name
args = sys.argv[1:]
with Path(os.environ["COMMAND_LOG"]).open("a") as log:
    log.write(
        json.dumps(
            {
                "command": command,
                "args": args,
                "branch": os.getenv("NIX_CONFIG_BRANCH"),
                "revision": os.getenv("NIX_CONFIG_REVISION"),
            }
        )
        + "\n"
    )

if command == "git":
    if "branch" in args:
        print(os.getenv("TEST_BRANCH", "feature/deploy"))
    elif "rev-parse" in args:
        print("abc123")
    elif "status" in args and os.getenv("TEST_DIRTY"):
        print(" M hosts/test/default.nix")
elif command == "hostname":
    print("controller")
elif command == "nix" and args[0] == "eval":
    if args[-1].endswith(".installer"):
        print(os.getenv("TEST_INSTALLER", "standard"))
    elif args[-1].endswith("nix.settings"):
        print(
            json.dumps(
                {
                    "substituters": ["https://cache.example"],
                    "trusted-public-keys": ["cache:key"],
                }
            )
        )
    else:
        print("test")
elif command == "age":
    Path(args[args.index("--output") + 1]).write_text("test identity")
elif command == "age-keygen":
    print(os.getenv("TEST_RECIPIENT", "age1test"))
elif command == "ssh":
    if args[-1] != "true":
        sys.stdin.read()
elif command == "nixos-anywhere":
    extra = Path(args[args.index("--extra-files") + 1])
    identity = extra / "persist/etc/agenix/host.agekey"
    assert identity.read_text() == "test identity"
    assert identity.stat().st_mode & 0o777 == 0o600
    sys.exit(int(os.getenv("TEST_INSTALL_EXIT", "0")))
