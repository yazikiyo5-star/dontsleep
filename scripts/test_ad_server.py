#!/usr/bin/env python3
"""Tiny local server for end-to-end-testing the ad pipeline.

- GET /house-ads.json  -> returns a 2-creative feed
- GET /pixel.gif       -> logs a line and returns a 1x1 GIF

Usage:
    python3 scripts/test_ad_server.py
Then set the app's Preferences -> JSON URL to:
    http://127.0.0.1:8789/house-ads.json
"""
import http.server
import socketserver
import json
import sys
import time

PORT = 8789
IMPRESSIONS_LOG = "/tmp/dontsleep_impressions.log"

FEED = [
    {
        "id": "test-a",
        "attribution": "Sponsored",
        "headline": "Test creative A",
        "body": "This is the first test banner",
        "imageUrl": None,
        "fallbackSymbol": "bolt.fill",
        "clickUrl": "https://example.com/a",
        "impressionUrl": f"http://127.0.0.1:{PORT}/pixel.gif?c=test-a",
    },
    {
        "id": "test-b",
        "attribution": "Community",
        "headline": "Test creative B",
        "body": "This is the second test banner",
        "imageUrl": None,
        "fallbackSymbol": "heart.fill",
        "clickUrl": "https://example.com/b",
        "impressionUrl": f"http://127.0.0.1:{PORT}/pixel.gif?c=test-b",
    },
]

# 1x1 transparent GIF
PIXEL = bytes.fromhex("47494638396101000100800000ffffff00000021f90401000001002c00000000010001000002024401003b")


class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("[%s] %s\n" % (self.log_date_time_string(), fmt % args))

    def do_GET(self):
        if self.path.startswith("/house-ads.json"):
            payload = json.dumps(FEED).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        if self.path.startswith("/pixel.gif"):
            with open(IMPRESSIONS_LOG, "a") as f:
                f.write(f"{time.time()} {self.path} UA={self.headers.get('User-Agent','?')}\n")
            self.send_response(200)
            self.send_header("Content-Type", "image/gif")
            self.send_header("Content-Length", str(len(PIXEL)))
            self.end_headers()
            self.wfile.write(PIXEL)
            return
        self.send_response(404)
        self.end_headers()


if __name__ == "__main__":
    open(IMPRESSIONS_LOG, "w").close()
    with socketserver.TCPServer(("127.0.0.1", PORT), H) as httpd:
        print(f"serving on http://127.0.0.1:{PORT} (log: {IMPRESSIONS_LOG})")
        httpd.serve_forever()
