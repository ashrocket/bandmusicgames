#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BMG_ROOT="$ROOT" python3 - <<'PY'
from __future__ import annotations

import functools
import pathlib
import re
import threading
import urllib.request
import os
from urllib.error import HTTPError
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

from playwright.sync_api import sync_playwright


ROOT = pathlib.Path(os.environ["BMG_ROOT"]).resolve()
ASHCODE = ROOT.parent


LIVE_CHECKS = [
    ("lobby", "https://bandmusicgames.party/"),
    ("goon-web", "https://forcuttinggrass.goon.bandmusicgames.party/"),
    ("lizzy-web", "https://lizzymcguire.narasroom.bandmusicgames.party/"),
    ("francis-web", "https://francis.darger.bandmusicgames.party/"),
]


LOCAL_CHECKS = [
    ("lobby", ROOT, 18081, r"BAND MUSIC GAMES|FOR CUTTING GRASS|FRANCIS|LIZZY"),
    ("goon-web", ASHCODE / "forcuttinggrass", 18082, r"GRASS CUTTER|spotify-overlay|game-container"),
    ("lizzy-web", ASHCODE / "lizzymcguire", 18083, r"HALF COURT HERO|feedback-overlay|mute-btn"),
    ("francis-web", ASHCODE / "francis", 18084, r"FRANCIS|dog-scene|login-prompt|card-scene"),
]


def check_live_http(name: str, url: str) -> None:
    print(f"HTTP {name:<18} {url}", flush=True)
    headers = {"User-Agent": "Mozilla/5.0 BandMusicGamesSmoke/1.0"}
    request = urllib.request.Request(url, headers=headers, method="HEAD")
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            if response.status >= 400:
                raise RuntimeError(f"{name} returned HTTP {response.status}")
    except HTTPError as error:
        if error.code != 403:
            raise
        fallback = urllib.request.Request(url, headers=headers, method="GET")
        with urllib.request.urlopen(fallback, timeout=15) as response:
            if response.status >= 400:
                raise RuntimeError(f"{name} returned HTTP {response.status}")


def start_server(name: str, directory: pathlib.Path, port: int) -> ThreadingHTTPServer:
    if not directory.exists():
        raise RuntimeError(f"{name} directory does not exist: {directory}")

    handler = functools.partial(SimpleHTTPRequestHandler, directory=str(directory))
    server = ThreadingHTTPServer(("127.0.0.1", port), handler)
    thread = threading.Thread(target=server.serve_forever, name=f"bmg-smoke-{name}", daemon=True)
    thread.start()
    print(f"SERVE {name:<17} http://127.0.0.1:{port}/", flush=True)
    return server


def check_browser_dom(playwright, name: str, port: int, pattern: str) -> None:
    url = f"http://127.0.0.1:{port}/"
    print(f"DOM  {name:<18} {pattern}", flush=True)
    browser = playwright.chromium.launch(headless=True)
    try:
        context = browser.new_context(java_script_enabled=False)
        page = context.new_page()
        page.goto(url, wait_until="domcontentloaded", timeout=10000)
        content = page.content()
        if re.search(pattern, content, flags=re.IGNORECASE) is None:
            raise RuntimeError(f"{name} DOM did not contain expected pattern: {pattern}")
    finally:
        browser.close()


def main() -> None:
    for name, url in LIVE_CHECKS:
        check_live_http(name, url)

    servers = []
    try:
        for name, directory, port, _pattern in LOCAL_CHECKS:
            servers.append(start_server(name, directory, port))

        with sync_playwright() as playwright:
            for name, _directory, port, pattern in LOCAL_CHECKS:
                check_browser_dom(playwright, name, port, pattern)
    finally:
        for server in servers:
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    main()
PY
