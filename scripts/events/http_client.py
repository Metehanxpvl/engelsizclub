"""HTTP: timeout, retry, robots.txt, ETag, nazik bekleme."""

from __future__ import annotations

import random
import time
from typing import Any
from urllib.parse import urljoin, urlparse
from urllib.robotparser import RobotFileParser

import httpx

USER_AGENT = "EngelsizClubBot/1.0 (+https://engelsizclub.com; aile etkinlikleri)"
TIMEOUT = 25.0
RETRY_STATUS = {429, 502, 503, 504}
MAX_RETRIES = 3


class FetchError(Exception):
    def __init__(self, url: str, reason: str) -> None:
        super().__init__(reason)
        self.url = url
        self.reason = reason


class EventHttp:
    def __init__(self, http: httpx.Client) -> None:
        self.http = http
        self._robots: dict[str, RobotFileParser | None] = {}
        self._etag: dict[str, str] = {}
        self._modified: dict[str, str] = {}

    def allowed(self, url: str) -> bool:
        parsed = urlparse(url)
        origin = f"{parsed.scheme}://{parsed.netloc}"
        if origin not in self._robots:
            rp = RobotFileParser()
            robots_url = urljoin(origin, "/robots.txt")
            try:
                res = self.http.get(
                    robots_url,
                    timeout=10.0,
                    headers={"User-Agent": USER_AGENT},
                )
                if res.status_code >= 400:
                    self._robots[origin] = None
                else:
                    rp.parse(res.text.splitlines())
                    self._robots[origin] = rp
            except Exception:
                self._robots[origin] = None
        rp = self._robots[origin]
        if rp is None:
            return True
        try:
            return rp.can_fetch(USER_AGENT, url)
        except Exception:
            return True

    def get_text(self, url: str) -> tuple[str, str] | None:
        """(final_url, text). robots yasaksa None."""
        if not self.allowed(url):
            return None
        headers = {
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/json,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "tr-TR,tr;q=0.9,en;q=0.7",
        }
        if url in self._etag:
            headers["If-None-Match"] = self._etag[url]
        if url in self._modified:
            headers["If-Modified-Since"] = self._modified[url]
        delay = 0.6
        last_exc: Exception | None = None
        for attempt in range(MAX_RETRIES):
            try:
                res = self.http.get(url, timeout=TIMEOUT, headers=headers)
            except Exception as exc:  # noqa: BLE001
                last_exc = exc
                time.sleep(delay)
                delay *= 2
                continue
            if res.status_code == 304:
                return url, ""
            if res.status_code in RETRY_STATUS and attempt < MAX_RETRIES - 1:
                time.sleep(delay + random.uniform(0, 0.3))
                delay *= 2
                continue
            if res.status_code >= 400:
                raise FetchError(url, f"HTTP {res.status_code}")
            etag = res.headers.get("ETag")
            if etag:
                self._etag[url] = etag
            modified = res.headers.get("Last-Modified")
            if modified:
                self._modified[url] = modified
            time.sleep(random.uniform(0.25, 0.55))
            return str(res.url), res.text
        raise FetchError(url, str(last_exc) if last_exc else "retry exhausted")


def new_client() -> httpx.Client:
    return httpx.Client(http2=False, follow_redirects=True, timeout=TIMEOUT)
