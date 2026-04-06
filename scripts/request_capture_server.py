#!/usr/bin/env python3
"""Small local HTTP server used by tests to capture app requests."""

from __future__ import annotations

import argparse
import json
import signal
import sys
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


class RequestStore:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._events: list[dict[str, Any]] = []

    def add(self, event: dict[str, Any]) -> None:
        with self._lock:
            self._events.append(event)

    def all(self) -> list[dict[str, Any]]:
        with self._lock:
            return list(self._events)

    def clear(self) -> None:
        with self._lock:
            self._events.clear()


def make_handler(store: RequestStore):
    class CaptureHandler(BaseHTTPRequestHandler):
        server_version = "RequestCapture/1.0"

        def log_message(self, fmt: str, *args: Any) -> None:
            # Keep output concise for CI logs.
            sys.stdout.write("LOG " + (fmt % args) + "\n")
            sys.stdout.flush()

        def _set_json(self, code: int = 200) -> None:
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
            self.end_headers()

        def do_OPTIONS(self) -> None:  # noqa: N802
            self._set_json(204)

        def do_GET(self) -> None:  # noqa: N802
            if self.path == "/health":
                self._set_json(200)
                self.wfile.write(json.dumps({"ok": True}).encode("utf-8"))
                return

            if self.path == "/requests":
                self._set_json(200)
                self.wfile.write(json.dumps({"events": store.all()}).encode("utf-8"))
                return

            self._set_json(404)
            self.wfile.write(json.dumps({"error": "not_found"}).encode("utf-8"))

        def do_POST(self) -> None:  # noqa: N802
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length) if length > 0 else b""
            body_text = body.decode("utf-8", errors="replace")

            if self.path == "/__reset":
                store.clear()
                self._set_json(200)
                self.wfile.write(json.dumps({"ok": True}).encode("utf-8"))
                return

            if self.path == "/__shutdown":
                self._set_json(200)
                self.wfile.write(json.dumps({"ok": True}).encode("utf-8"))
                threading.Thread(target=self.server.shutdown, daemon=True).start()
                return

            event = {
                "time": _utc_now_iso(),
                "method": self.command,
                "path": self.path,
                "headers": {k.lower(): v for k, v in self.headers.items()},
                "body": body_text,
            }
            store.add(event)

            self._set_json(202)
            self.wfile.write(json.dumps({"accepted": True}).encode("utf-8"))

    return CaptureHandler


def main() -> int:
    parser = argparse.ArgumentParser(description="Request capture server for tests")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=0)
    args = parser.parse_args()

    store = RequestStore()
    httpd = ThreadingHTTPServer((args.host, args.port), make_handler(store))

    def _shutdown_handler(_signum: int, _frame: Any) -> None:
        httpd.shutdown()

    signal.signal(signal.SIGTERM, _shutdown_handler)
    signal.signal(signal.SIGINT, _shutdown_handler)

    host, port = httpd.server_address
    print(f"SERVER_READY {host}:{port}", flush=True)
    httpd.serve_forever()
    httpd.server_close()
    print("SERVER_STOPPED", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
