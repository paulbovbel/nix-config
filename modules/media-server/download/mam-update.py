#!/usr/bin/env python3
import argparse
from dataclasses import dataclass
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import subprocess
import sys
import time


MAM_API = "https://t.myanonamouse.net/json/dynamicSeedbox.php"
IP_CHECK_URL = "https://checkip.amazonaws.com"
CONTAINER_CONFIG_DIR = "/config"
AUTOBRR_API_URL = "http://127.0.0.1:7474/autobrr/api/indexer"
API_RETRY_COUNT = 5
API_RETRY_DELAY_SECONDS = 2


@dataclass(frozen=True)
class MamTarget:
    container: str
    container_user: str
    interface: str
    config_dir: Path


def run(args, *, input_text=None):
    return subprocess.run(
        args,
        input=input_text,
        text=True,
        capture_output=True,
        check=True,
    ).stdout


def podman_exec(container, args, *, input_text=None, user=None):
    command = ["podman", "exec"]
    if user:
        command.extend(["--user", user])
    if input_text is not None:
        command.append("--interactive")
    return run([*command, container, *args], input_text=input_text)


def curl(
    container,
    url,
    *,
    description,
    user=None,
    method=None,
    headers=(),
    input_text=None,
    interface=None,
    max_time=30,
    fail_with_body=True,
    cookie=None,
    cookie_jar=None,
):
    args = [
        "--fail-with-body" if fail_with_body else "--fail",
        "--silent",
        "--show-error",
        "--max-time",
        str(max_time),
    ]
    if interface is not None:
        args.extend(["--interface", interface])
    if method is not None:
        args.extend(["--request", method])
    for header in headers:
        args.extend(["--header", header])
    if input_text is not None:
        args.extend(["--data-binary", "@-"])
    if cookie is not None:
        args.extend(["--cookie", cookie])
    if cookie_jar is not None:
        args.extend(["--cookie-jar", cookie_jar])
    try:
        return podman_exec(
            container, ["curl", *args, url], input_text=input_text, user=user
        )
    except subprocess.CalledProcessError as error:
        details = []
        if error.stderr and error.stderr.strip():
            details.append(f"stderr: {error.stderr.strip()}")
        if error.stdout and error.stdout.strip():
            details.append(f"response body: {error.stdout.strip()}")
        detail = "; ".join(details) or str(error)
        raise RuntimeError(
            f"{description} failed in container {container}: {detail}"
        ) from error


def fingerprint(value):
    return hashlib.sha256(value.encode()).hexdigest()


def read_text(path):
    try:
        return path.read_text().strip()
    except FileNotFoundError:
        return ""


def write_private(path, value):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    path.write_text(f"{value}\n")
    path.chmod(0o600)


def replace_json_preserving_metadata(path, value):
    stat = path.stat()
    temp_path = path.with_suffix(path.suffix + ".tmp")
    temp_path.write_text(json.dumps(value, indent=2))
    os.chown(temp_path, stat.st_uid, stat.st_gid)
    os.chmod(temp_path, stat.st_mode & 0o777)
    temp_path.replace(path)


def remove_file(path):
    try:
        path.unlink()
    except FileNotFoundError:
        pass


def mam_id_from_env(name):
    value = os.environ.get(name, "")
    if not value:
        raise RuntimeError(f"missing required env var: {name}")
    return value


def wait_for_json(fetch, description):
    last_error = None
    for attempt in range(API_RETRY_COUNT):
        try:
            response = fetch()
            if not response.strip():
                raise RuntimeError("empty response")
            return json.loads(response)
        except (
            RuntimeError,
            subprocess.CalledProcessError,
            json.JSONDecodeError,
        ) as error:
            last_error = error
            if attempt == API_RETRY_COUNT - 1:
                detail = str(last_error)
                if isinstance(last_error, subprocess.CalledProcessError):
                    detail = (last_error.stderr or last_error.stdout or detail).strip()
                raise RuntimeError(
                    f"timed out waiting for {description}: {detail}"
                ) from last_error
            time.sleep(API_RETRY_DELAY_SECONDS)
    raise AssertionError("unreachable")


def update_mam_ip(target, mam_id):
    cached_ip = target.config_dir / f"mam.ip.{target.interface}"
    cookie_jar = target.config_dir / f"mam.cookies.{target.interface}"
    cookie_fingerprint = (
        target.config_dir / f"mam.cookie-fingerprint.{target.interface}"
    )
    container_cookie_jar = f"{CONTAINER_CONFIG_DIR}/mam.cookies.{target.interface}"

    new_fingerprint = fingerprint(mam_id)
    if read_text(cookie_fingerprint) != new_fingerprint:
        remove_file(cached_ip)
        remove_file(cookie_jar)

    new_ip = curl(
        target.container,
        IP_CHECK_URL,
        description=f"checking egress IP for {target.interface}",
        user=target.container_user,
        interface=target.interface,
        max_time=10,
        fail_with_body=False,
    ).strip()
    try:
        ipaddress.ip_address(new_ip)
    except ValueError as error:
        raise RuntimeError(
            f"invalid IP from check service for {target.interface}: {new_ip}"
        ) from error

    old_ip = read_text(cached_ip)
    if new_ip == old_ip:
        print(f"MAM IP unchanged for {target.interface}: {new_ip}")
        return

    print(f"Updating MAM IP for {target.interface}: {old_ip or '<none>'} -> {new_ip}")
    response = curl(
        target.container,
        MAM_API,
        description=f"updating MAM dynamic seedbox IP for {target.interface}",
        user=target.container_user,
        interface=target.interface,
        cookie=container_cookie_jar if cookie_jar.exists() else f"mam_id={mam_id}",
        cookie_jar=container_cookie_jar,
    )

    try:
        body = json.loads(response)
    except json.JSONDecodeError:
        body = None
    if isinstance(body, dict) and body.get("success") is False:
        raise RuntimeError(
            f"MAM API rejected update for {target.interface}: {response}"
        )

    print(response.strip())
    write_private(cached_ip, new_ip)
    write_private(cookie_fingerprint, new_fingerprint)
    print(f"Updated MAM IP for {target.interface}: {old_ip} -> {new_ip}")


def replace_jackett_mam_id(value, mam_id):
    if not isinstance(value, list):
        raise RuntimeError("expected Jackett MyAnonamouse config array")

    ids = {item.get("id"): item for item in value if isinstance(item, dict)}
    mam_item = ids.get("mam_id")
    cookie_item = ids.get("cookieheader")
    if mam_item is None:
        raise RuntimeError("mam_id field not found in Jackett config")
    if cookie_item is None:
        raise RuntimeError("cookieheader field not found in Jackett config")

    changed = False
    cookie_header = f"mam_id={mam_id}"
    if mam_item.get("value") != mam_id:
        mam_item["value"] = mam_id
        changed = True
    if cookie_item.get("value") != cookie_header:
        cookie_item["value"] = cookie_header
        changed = True
    return changed


def update_jackett(target, mam_id):
    config_path = target.config_dir / "Jackett" / "Indexers" / "myanonamouse.json"
    if not config_path.exists():
        raise RuntimeError(f"Jackett MyAnonamouse config not found: {config_path}")

    old_config = config_path.read_text()
    config = json.loads(old_config)
    if not replace_jackett_mam_id(config, mam_id):
        print("Jackett MyAnonamouse mam_id unchanged")
        return

    print("Updating Jackett MyAnonamouse mam_id")
    backup_path = config_path.with_suffix(config_path.suffix + ".bak")
    backup_path.write_text(old_config)
    replace_json_preserving_metadata(config_path, config)
    run(["podman", "restart", target.container])
    print("Updated Jackett MyAnonamouse mam_id")


def autobrr_curl(token, url, *, method="GET", input_text=None):
    headers = ["X-API-Token: {token}".format(token=token)]
    if input_text is not None:
        headers.append("Content-Type: application/json")
    return curl(
        "autobrr",
        url,
        description=f"calling autobrr API {method} {url}",
        method=None if method == "GET" else method,
        headers=headers,
        input_text=input_text,
    )


def update_autobrr(mam_id):
    token = mam_id_from_env("AUTOBRR_API_TOKEN")
    print("Fetching autobrr indexers")
    indexers = wait_for_json(
        lambda: autobrr_curl(token, AUTOBRR_API_URL), "autobrr API"
    )
    if not isinstance(indexers, list):
        raise RuntimeError("expected autobrr indexer list")

    indexer_id = None
    for indexer in indexers:
        if not isinstance(indexer, dict):
            continue
        names = {
            str(indexer.get("identifier", "")).lower(),
            str(indexer.get("identifier_external", "")).lower(),
            str(indexer.get("name", "")).lower(),
        }
        if "myanonamouse" in names:
            indexer_id = indexer.get("id")
            break
    if indexer_id is None:
        raise RuntimeError("autobrr MyAnonamouse indexer not found")

    print(f"Updating autobrr MyAnonamouse indexer {indexer_id}")
    indexer = json.loads(autobrr_curl(token, f"{AUTOBRR_API_URL}/{indexer_id}"))
    settings = indexer.get("settings")
    if not isinstance(settings, dict):
        settings = {}
        indexer["settings"] = settings
    settings["cookie"] = f"mam_id={mam_id};"

    response = autobrr_curl(
        token,
        f"{AUTOBRR_API_URL}/{indexer_id}",
        method="PUT",
        input_text=json.dumps(indexer),
    )
    print(response.strip())
    print("Updated autobrr MyAnonamouse mam_id")


def update_indexer_apps(target, mam_id):
    app_fingerprint = target.config_dir / "mam.app-fingerprint"
    new_fingerprint = fingerprint(mam_id)
    if read_text(app_fingerprint) == new_fingerprint:
        print("MyAnonamouse app configs unchanged")
        return

    update_jackett(target, mam_id)
    update_autobrr(mam_id)
    write_private(app_fingerprint, new_fingerprint)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--container-user", required=True)
    parser.add_argument("--qbittorrent-config-dir", required=True)
    parser.add_argument("--jackett-config-dir", required=True)
    parser.add_argument("--rotate-app-configs", action="store_true")
    args = parser.parse_args()

    torrent = MamTarget(
        container="qbittorrent",
        container_user=args.container_user,
        interface="wg0",
        config_dir=Path(args.qbittorrent_config_dir),
    )
    indexer = MamTarget(
        container="jackett",
        container_user=args.container_user,
        interface="eth0",
        config_dir=Path(args.jackett_config_dir),
    )
    return args.rotate_app_configs, torrent, indexer


def main():
    rotate_app_configs, torrent, indexer = parse_args()

    try:
        torrent_mam_id = mam_id_from_env("MAM_ID_TORRENT")
        indexer_mam_id = mam_id_from_env("MAM_ID_INDEXER")

        update_mam_ip(torrent, torrent_mam_id)
        update_mam_ip(indexer, indexer_mam_id)
        if rotate_app_configs:
            update_indexer_apps(indexer, indexer_mam_id)
    except (RuntimeError, subprocess.CalledProcessError) as error:
        if isinstance(error, subprocess.CalledProcessError):
            sys.stderr.write(error.stderr)
        else:
            sys.stderr.write(f"{error}\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
