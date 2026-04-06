#!/usr/bin/env python3

"""Convenience launcher for the request capture server.

This lets the server be started from the project root with:

    python3 request_capture_server.py --host 127.0.0.1 --port 54010

The implementation lives in scripts/request_capture_server.py.
"""

from __future__ import annotations

from pathlib import Path
import runpy


def main() -> None:
    script_path = Path(__file__).with_name('scripts').joinpath('request_capture_server.py')
    runpy.run_path(str(script_path), run_name='__main__')


if __name__ == '__main__':
    main()