#!/usr/bin/env python3
"""Mirror Gluetun's forwarded port into qBittorrent's listen settings."""

import asyncio
import json
import logging
import signal
from urllib.parse import urlencode
from urllib.request import ProxyHandler, Request, build_opener

GLUETUN_PORTFORWARD = "http://127.0.0.1:8000/v1/portforward"
QBITTORRENT_API = "http://127.0.0.1:8080/api/v2/app"
POLL_SECONDS = 2
REQUEST_TIMEOUT = 2
RESPONSE_LIMIT = 65536
LOG = logging.getLogger("port-sync")


def fetch(url, data=None):
    # Never route loopback API calls through an inherited HTTP proxy.
    opener = build_opener(ProxyHandler({}))
    with opener.open(Request(url, data=data), timeout=REQUEST_TIMEOUT) as response:
        return json.loads(response.read(RESPONSE_LIMIT) or b"null")


async def request(url, data=None):
    """Return the decoded JSON body; urllib is blocking, so use a worker thread."""
    return await asyncio.to_thread(fetch, url, data)


def validate_port(port):
    if isinstance(port, bool) or not isinstance(port, int) or not 0 <= port <= 65535:
        raise ValueError(f"invalid forwarded port: {port!r}")
    return port


def preferences(port):
    """Bind the tunnel only while a forward is active; fail closed otherwise."""
    validate_port(port)
    if not port:
        # qBittorrent refuses to clear random_port while no port is set, so
        # claiming one here would never converge. The loopback binding is what
        # fails closed; the stale port is unreachable on it.
        return {"current_network_interface": "lo", "upnp": False}
    return {
        "listen_port": port,
        "current_network_interface": "wg0",
        "random_port": False,
        "upnp": False,
    }


async def forwarded_port():
    value = await request(GLUETUN_PORTFORWARD)
    if "ports" in value:
        # Newer Gluetun reports a list, and an empty one means no forward.
        ports = value["ports"]
        port = ports[0] if ports else 0
    else:
        port = value["port"]
    return validate_port(port)


async def reconcile(port):
    """Apply the desired listen settings, returning them only when they changed."""
    desired = preferences(port)
    current = await request(f"{QBITTORRENT_API}/preferences")
    if all(current.get(key) == value for key, value in desired.items()):
        return None
    body = urlencode({"json": json.dumps(desired)}).encode()
    await request(f"{QBITTORRENT_API}/setPreferences", body)
    return desired


async def sleep_unless_stopped(stopped, seconds):
    try:
        await asyncio.wait_for(stopped.wait(), timeout=seconds)
    except TimeoutError:
        pass


async def run(stopped):
    # Polling alone recovers forward changes, qBittorrent restarts, and our own
    # restarts; qBittorrent's startup hook binds loopback until we observe one.
    failed = False
    while not stopped.is_set():
        try:
            port = await forwarded_port()
            if await reconcile(port) is not None:
                LOG.info(
                    "Bound qBittorrent to %s",
                    f"wg0 port {port}" if port else "loopback, no forward",
                )
            if failed:
                LOG.info("API synchronization recovered")
            failed = False
        except (OSError, ValueError, KeyError, TypeError) as error:
            if not failed:
                LOG.warning(
                    "API unavailable (%s); retrying every %ds", error, POLL_SECONDS
                )
            failed = True
        await sleep_unless_stopped(stopped, POLL_SECONDS)


async def main():
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    stopped = asyncio.Event()
    loop = asyncio.get_running_loop()
    for number in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(number, stopped.set)
    await run(stopped)


if __name__ == "__main__":
    asyncio.run(main())
