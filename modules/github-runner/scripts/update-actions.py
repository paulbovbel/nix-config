"""Refresh SHA-pinned GitHub Actions using their version comments."""

import re
import subprocess
from pathlib import Path

PIN = re.compile(
    r"(?P<prefix>\buses:\s+)(?P<action>[\w.-]+/[\w./-]+)@"
    r"(?P<sha>[0-9a-f]{40})(?P<comment>\s+#\s*)"
    r"(?P<version>v\d+(?:\.\d+){0,2})(?=\s|$)"
)


def resolve(action, version):
    """Resolve a major channel or the newest stable release in that major."""
    repository = "/".join(action.split("/")[:2])
    major = version.split(".")[0]
    result = subprocess.run(
        ["git", "ls-remote", "--tags", f"https://github.com/{repository}.git"],
        check=True,
        capture_output=True,
        text=True,
    )
    refs = dict(line.split()[::-1] for line in result.stdout.splitlines())
    if "." not in version:
        tag = version
    else:
        releases = []
        for ref in refs:
            match = re.fullmatch(rf"refs/tags/{re.escape(major)}\.(\d+)\.(\d+)", ref)
            if match:
                releases.append((tuple(map(int, match.groups())), ref))
        if not releases:
            raise ValueError(f"No stable {major} releases for {repository}")
        tag = max(releases)[1].removeprefix("refs/tags/")
    ref = f"refs/tags/{tag}"
    sha = refs.get(ref + "^{}", refs.get(ref))
    if sha is None or not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError(f"No valid commit for {repository}@{tag}")
    return sha, tag


def main():
    cache = {}

    def replace(match):
        action, version = match["action"], match["version"]
        key = (action, version)
        if key not in cache:
            cache[key] = resolve(action, version)
            print(f"Resolved {action}@{version}: {cache[key][0]} ({cache[key][1]})")
        sha, tag = cache[key]
        return f"{match['prefix']}{action}@{sha}{match['comment']}{tag}"

    updates = {}
    for path in sorted(Path(".github/workflows").iterdir()):
        if path.suffix not in {".yml", ".yaml"}:
            continue
        original = path.read_text()
        updated = PIN.sub(replace, original)
        if updated != original:
            updates[path] = updated
    # Resolve every remote before modifying any workflow.
    for path, updated in updates.items():
        path.write_text(updated)


if __name__ == "__main__":
    main()
