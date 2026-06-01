import argparse
import asyncio
import os
import sys

from aiohttp import ClientSession

PROXY_STATUS_URL = os.environ.get(
    "LLAMA_PROXY_STATUS_URL", "http://white-tower:11434/_status"
)
PROXY_HEALTH_URL = os.environ.get(
    "LLAMA_PROXY_HEALTH_URL", "http://white-tower:11434/health"
)
WAIT_TIMEOUT_SECONDS = float(os.environ.get("LLAMA_WAIT_TIMEOUT", "300"))
WOL_SSH_HOST = os.environ.get("LLAMA_WOL_SSH_HOST", "root@unifi")
WOL_SCRIPT = os.environ.get("LLAMA_WOL_SCRIPT", "./wol.sh")
WOL_BROADCAST = os.environ.get("LLAMA_WOL_BROADCAST", "192.168.1.255")
WOL_PORT = os.environ.get("LLAMA_WOL_PORT", "9")
WOL_MAC = os.environ.get("LLAMA_WOL_MAC", "18:c0:4d:a9:3c:ae")


def log_stage(payload: dict[str, str] | None, verbose: bool) -> None:
    if not verbose:
        return
    if payload is None:
        return
    stage = payload.get("stage", "")
    details = payload.get("details", "")
    msg = f"stage={stage}"
    if details:
        msg += f" details={details}"
    print(msg, file=sys.stderr, flush=True)


async def fetch_status(session: ClientSession) -> dict[str, str] | None:
    async with session.get(PROXY_STATUS_URL) as resp:
        if resp.status != 200:
            return None
        return await resp.json()


async def trigger_start(session: ClientSession) -> bool:
    try:
        async with session.get(PROXY_HEALTH_URL) as resp:
            await resp.read()
            return resp.status == 200
    except Exception:
        return False


async def wake_white_tower(verbose: bool) -> None:
    remote_cmd = f"BROADCAST={WOL_BROADCAST} PORT={WOL_PORT} {WOL_SCRIPT} {WOL_MAC}"
    proc = await asyncio.create_subprocess_exec(
        "ssh",
        WOL_SSH_HOST,
        remote_cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    if proc.returncode != 0:
        msg = (
            stderr.decode(errors="replace").strip()
            or stdout.decode(errors="replace").strip()
        )
        raise RuntimeError(f"WoL command failed via {WOL_SSH_HOST}: {msg}")
    if verbose:
        log_stage(
            {
                "stage": "wake_sent",
                "details": f"wol sent to {WOL_MAC} via {WOL_SSH_HOST}",
            },
            verbose,
        )


async def poll_until_ready(verbose: bool) -> None:
    timeout_at = asyncio.get_running_loop().time() + WAIT_TIMEOUT_SECONDS
    last_stage = ""
    async with ClientSession(timeout=None) as session:
        while asyncio.get_running_loop().time() < timeout_at:
            payload = await fetch_status(session)
            if payload is not None:
                current_stage = payload.get("stage", "")
                if current_stage != last_stage:
                    log_stage(payload, verbose)
                    last_stage = current_stage
                if current_stage == "ready":
                    return

            await trigger_start(session)
            await asyncio.sleep(1)

    raise TimeoutError(
        f"timed out waiting for llama proxy readiness after {WAIT_TIMEOUT_SECONDS}s"
    )


async def run_opencode(args: list[str]) -> int:
    proc = await asyncio.create_subprocess_exec("opencode", *args)
    return await proc.wait()


async def main_async(opencode_args: list[str], verbose: bool) -> None:
    await wake_white_tower(verbose)
    await poll_until_ready(verbose)
    code = await run_opencode(opencode_args)
    raise SystemExit(code)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Wait for llama proxy and launch opencode"
    )
    parser.add_argument(
        "--quiet", action="store_true", help="suppress startup stage logging"
    )
    parser.add_argument(
        "opencode_args",
        nargs=argparse.REMAINDER,
        help="arguments forwarded to opencode",
    )
    return parser.parse_args(argv)


def main() -> None:
    ns = parse_args(sys.argv[1:])
    forwarded = ns.opencode_args
    if forwarded and forwarded[0] == "--":
        forwarded = forwarded[1:]
    asyncio.run(main_async(forwarded, verbose=not ns.quiet))


if __name__ == "__main__":
    main()
