import asyncio
import logging
import time
from enum import StrEnum
from ipaddress import ip_address
from typing import Self

from aiohttp import ClientError, ClientSession, web

LLAMA_HOST = "127.0.0.1"
LLAMA_PORT = 18080
INACTIVITY_SECONDS = 300
LOGOUT_WARNING_SECONDS = 60
MODEL_REPO = "HauhauCS/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive"
MODEL_FILENAME = "Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-Q4_K_M.gguf"
LOGGER = logging.getLogger(__name__)

SYSTEMD_INHIBIT_CMD = [
    "systemd-inhibit",
    "--what",
    "sleep",
    "--why",
    "llama.cpp inference in progress",
    "--mode",
    "block",
]


class LlamaFlags:
    def __init__(self) -> None:
        self._flags: list[str] = []

    def add(self, key: str, value: str | None = None) -> Self:
        if value is None:
            self._flags.append(key)
        else:
            self._flags.extend([key, str(value)])
        return self

    def to_list(self) -> list[str]:
        return self._flags

    @classmethod
    def build(cls) -> list[str]:
        flags = cls()
        flags.add("--host", LLAMA_HOST)
        flags.add("--port", str(LLAMA_PORT))
        flags.add("--jinja")
        flags.add("--ctx-size", "65536")
        flags.add("--fit", "on")
        flags.add("--fit-ctx", "65536")
        flags.add("--fit-target", "1536")
        flags.add("--flash-attn", "on")
        flags.add("--no-mmap")
        flags.add("--mlock")
        flags.add("--batch-size", "1024")
        flags.add("--ubatch-size", "512")
        flags.add("--parallel", "1")
        flags.add("--cache-type-k", "q8_0")
        flags.add("--cache-type-v", "q8_0")
        flags.add("--temp", "0.6")
        flags.add("--top-p", "0.95")
        flags.add("--top-k", "20")
        flags.add("--min-p", "0.0")
        flags.add("--presence-penalty", "0.0")
        flags.add("--repeat-penalty", "1.0")
        flags.add("--reasoning-budget", "-1")
        flags.add("--chat-template-kwargs", '{"preserve_thinking": true}')
        flags.add("--hf-repo", MODEL_REPO)
        flags.add("--hf-file", MODEL_FILENAME)
        return flags.to_list()


class Stage(StrEnum):
    DOWNLOADING = "downloading_model"
    STARTING = "starting_llama_cpp"
    READY = "ready"
    STOPPING = "stopping"


logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")


async def _run_command(*cmd: str) -> tuple[int, str, str]:
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await proc.communicate()
    except (asyncio.CancelledError, KeyboardInterrupt):
        if proc.returncode is None:
            proc.kill()
            await proc.wait()
        raise
    return proc.returncode, stdout.decode().strip(), stderr.decode().strip()


async def _logout_graphical_sessions() -> None:
    code, out, err = await _run_command(
        "graphical-sessions",
        "logout",
        "--warning-seconds",
        str(LOGOUT_WARNING_SECONDS),
    )
    if code != 0:
        raise RuntimeError(f"failed to log out graphical sessions: {err or out}")
    if err:
        LOGGER.info("graphical session logout: %s", err)


class StageTracker:
    def __init__(self) -> None:
        self.stage: Stage = Stage.STARTING
        self.details: str = ""

    def set(self, stage: Stage, details: str = "") -> None:
        self.stage = stage
        self.details = details
        if details:
            LOGGER.info("stage=%s details=%s", stage, details)
        else:
            LOGGER.info("stage=%s", stage)

    def snapshot(self) -> dict[str, str]:
        return {"stage": self.stage, "details": self.details}


class LlamaProcessManager:
    def __init__(
        self,
        session: ClientSession,
        stage: StageTracker,
    ) -> None:
        self.session = session
        self.stage = stage
        self.proc = None
        self.proc_lock = asyncio.Lock()
        self.starting = False

    def is_running(self) -> bool:
        return self.proc is not None and self.proc.returncode is None

    async def ensure_running(self, allow_logout: bool) -> None:
        async with self.proc_lock:
            if self.is_running():
                return
            self.stage.set(Stage.STARTING)
            if allow_logout:
                await _logout_graphical_sessions()
            else:
                LOGGER.info("skipping graphical session logout for local request")
            self.starting = True
            self.proc = await asyncio.create_subprocess_exec(
                *SYSTEMD_INHIBIT_CMD, *["llama-server"], *LlamaFlags.build()
            )

        deadline = time.time() + 120
        health_url = f"http://{LLAMA_HOST}:{LLAMA_PORT}/health"
        while time.time() < deadline:
            if self.proc.returncode is not None:
                raise RuntimeError("llama-server exited during startup")
            try:
                async with self.session.get(health_url) as resp:
                    if resp.status == 200:
                        self.stage.set(Stage.READY)
                        self.starting = False
                        return
            except ClientError:
                LOGGER.debug("llama-server health check failed during startup")
            await asyncio.sleep(0.5)
        raise RuntimeError("llama-server startup timed out")

    async def stop(self) -> None:
        if not self.is_running():
            return
        self.stage.set(Stage.STOPPING)
        self.starting = False
        self.proc.terminate()
        try:
            await asyncio.wait_for(self.proc.wait(), timeout=20)
        except asyncio.TimeoutError:
            self.proc.kill()
            await self.proc.wait()


class LlamaProxy:
    def __init__(self) -> None:
        self.last_activity = 0.0
        self.llama_manager: LlamaProcessManager | None = None
        self.session: ClientSession | None = None
        self.reaper_task: asyncio.Task[None] | None = None
        self.model_ready = asyncio.Event()
        self.stage = StageTracker()

    def set_stage(self, stage: Stage, details: str = "") -> None:
        self.stage.set(stage, details)

    async def ensure_model_present(self) -> None:
        self.set_stage(Stage.DOWNLOADING, f"{MODEL_REPO}/{MODEL_FILENAME}")
        code, out, err = await _run_command(
            "hf", "download", MODEL_REPO, MODEL_FILENAME
        )
        if code != 0:
            raise RuntimeError(
                f"model download failed with exit code {code}: {err or out}"
            )

    def request_allows_logout(self, request: web.Request) -> bool:
        peer_name = request.transport.get_extra_info("peername")
        if not peer_name:
            return True
        host = peer_name[0]
        try:
            return not ip_address(host).is_loopback
        except ValueError:
            LOGGER.warning("failed to parse request peer address: %r", host)
            return True

    async def ensure_llama_running(self, request: web.Request) -> None:
        await self.model_ready.wait()
        self.last_activity = time.time()
        assert self.llama_manager is not None
        await self.llama_manager.ensure_running(self.request_allows_logout(request))

    async def stage_handler(self, _request: web.Request) -> web.Response:
        assert self.llama_manager is not None
        return web.json_response(
            {
                **self.stage.snapshot(),
                "model_ready": self.model_ready.is_set(),
                "llama_running": self.llama_manager.is_running(),
            }
        )

    async def proxy_handler(self, request: web.Request) -> web.StreamResponse:
        await self.ensure_llama_running(request)
        self.last_activity = time.time()

        upstream = f"http://{LLAMA_HOST}:{LLAMA_PORT}{request.rel_url}"
        body = await request.read()
        headers = {k: v for k, v in request.headers.items() if k.lower() != "host"}

        assert self.session is not None
        async with self.session.request(
            request.method, upstream, headers=headers, data=body
        ) as resp:
            response = web.StreamResponse(status=resp.status, reason=resp.reason)
            for k, v in resp.headers.items():
                if k.lower() in {
                    "connection",
                    "transfer-encoding",
                    "keep-alive",
                    "proxy-authenticate",
                    "proxy-authorization",
                    "te",
                    "trailers",
                    "upgrade",
                }:
                    continue
                response.headers[k] = v
            await response.prepare(request)
            async for chunk in resp.content.iter_chunked(65536):
                await response.write(chunk)
            await response.write_eof()
            return response

    async def idle_reaper(self) -> None:
        assert self.llama_manager is not None
        while True:
            await asyncio.sleep(5)
            if not self.llama_manager.is_running():
                continue
            if self.llama_manager.starting:
                continue
            if time.time() - self.last_activity < INACTIVITY_SECONDS:
                continue
            async with self.llama_manager.proc_lock:
                if not self.llama_manager.is_running():
                    continue
                LOGGER.info("stopping llama-server after inactivity")
                await self.llama_manager.stop()

    async def on_startup(self, _app: web.Application) -> None:
        self.set_stage(Stage.STARTING)
        self.session = ClientSession(timeout=None)
        self.llama_manager = LlamaProcessManager(self.session, self.stage)
        await self.ensure_model_present()
        self.model_ready.set()
        self.reaper_task = asyncio.create_task(self.idle_reaper())
        self.set_stage(Stage.READY)
        LOGGER.info("llama proxy started on 0.0.0.0:11434")

    async def on_cleanup(self, _app: web.Application) -> None:
        assert self.reaper_task is not None
        self.reaper_task.cancel()
        try:
            await self.reaper_task
        except asyncio.CancelledError:
            pass
        assert self.session is not None
        await self.session.close()
        if self.llama_manager is not None:
            await self.llama_manager.stop()

    def run(self) -> None:
        app = web.Application(client_max_size=1024**3)
        app.router.add_get("/_status", self.stage_handler)
        app.router.add_route("*", "/{tail:.*}", self.proxy_handler)
        app.on_startup.append(self.on_startup)
        app.on_cleanup.append(self.on_cleanup)
        web.run_app(app, host="0.0.0.0", port=11434, access_log=None)


if __name__ == "__main__":
    LlamaProxy().run()
