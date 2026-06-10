"""mitmproxy addon: dump okcdn call signaling (ws2 WebSocket + HTTP) to a log."""
import json
import time

from mitmproxy import http, ctx

LOG = r"C:\Users\klockky\Komet\docs\ws2_capture.log"
HOSTS = ("okcdn.ru", "videowebrtc")


def _interesting(host: str) -> bool:
    return any(h in host for h in HOSTS)


def _w(line: str) -> None:
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def _fmt(content: bytes) -> str:
    try:
        text = content.decode("utf-8")
        try:
            return json.dumps(json.loads(text), ensure_ascii=False, indent=2)
        except Exception:
            return text
    except Exception:
        return "HEX " + content.hex()


def websocket_start(flow: http.HTTPFlow) -> None:
    if not _interesting(flow.request.pretty_host):
        return
    _w("=" * 70)
    _w(f"# WS OPEN  {flow.request.pretty_host}  {flow.request.path}")
    _w(f"  headers: {dict(flow.request.headers)}")
    _w("=" * 70)


def websocket_message(flow: http.HTTPFlow) -> None:
    if not _interesting(flow.request.pretty_host):
        return
    msg = flow.websocket.messages[-1]
    arrow = "TX (client->server)" if msg.from_client else "RX (server->client)"
    ts = time.strftime("%H:%M:%S")
    _w(f"\n--- {arrow}  {ts}  {len(msg.content)} B  host={flow.request.pretty_host} ---")
    _w(_fmt(msg.content))


def websocket_end(flow: http.HTTPFlow) -> None:
    if not _interesting(flow.request.pretty_host):
        return
    _w(f"\n# WS CLOSE {flow.request.pretty_host}\n")


def response(flow: http.HTTPFlow) -> None:
    host = flow.request.pretty_host
    if not _interesting(host):
        return
    if flow.websocket is not None:
        return
    _w("\n" + "#" * 70)
    _w(f"# HTTP {flow.request.method} {host}{flow.request.path} -> {flow.response.status_code}")
    if flow.request.content:
        _w("  REQ: " + _fmt(flow.request.content)[:2000])
    if flow.response.content:
        _w("  RES: " + _fmt(flow.response.content)[:2000])


def load(loader) -> None:
    _w(f"\n\n########## capture session start {time.strftime('%Y-%m-%d %H:%M:%S')} ##########")
    ctx.log.info("ws2_dump addon loaded")
