#!/usr/bin/env python3
"""Fake Xtream-Codes panel for testing the Flutter client offline.

Serves:
  /player_api.php            login, live/vod/series categories and streams, short EPG
  /get.php                   a minimal M3U playlist
  /movie/<u>/<p>/<id>.<ext>  a 20 s generated test clip
  /live/<u>/<p>/<id>.<ext>   same clip
  /xmltv.php                 a small XMLTV document

Run:  python3 mock_panel.py [port]   (default 8420)
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8420
# --open: answer list requests without credentials, to exercise the app's
# anonymous "panel is open" path.
OPEN = "--open" in sys.argv
CLIP = "/tmp/test_pattern.mp4"
VALID = {"username": "demo", "password": "demo"}

LIVE_CATS = [{"category_id": "1", "category_name": "News"},
             {"category_id": "2", "category_name": "Sports"}]
LIVE = [
    {"num": 1, "name": "Test Pattern One HD", "stream_type": "live", "stream_id": 101,
     "stream_icon": "", "epg_channel_id": "tp1", "added": "1700000000",
     "category_id": "1", "custom_sid": "", "tv_archive": 0, "direct_source": ""},
    {"num": 2, "name": "Test Pattern Two", "stream_type": "live", "stream_id": 102,
     "stream_icon": "", "epg_channel_id": "tp2", "added": "1700000000",
     "category_id": "1", "custom_sid": "", "tv_archive": 0, "direct_source": ""},
    {"num": 3, "name": "Sports Feed 24/7", "stream_type": "live", "stream_id": 103,
     "stream_icon": "", "epg_channel_id": "tp3", "added": "1700000000",
     "category_id": "2", "custom_sid": "", "tv_archive": 1, "direct_source": ""},
]
VOD_CATS = [{"category_id": "10", "category_name": "Films"}]
VOD = [{"num": 1, "name": "Local Test Movie", "stream_type": "movie", "stream_id": 501,
        "stream_icon": "", "rating": "7.5", "rating_5based": 3.8, "added": "1700000000",
        "category_id": "10", "container_extension": "mp4", "custom_sid": "",
        "direct_source": ""}]
SERIES_CATS = [{"category_id": "20", "category_name": "Drama"}]
SERIES = [{"num": 1, "name": "Local Test Series", "series_id": 901, "cover": "",
           "plot": "A synthetic series for testing.", "cast": "", "director": "",
           "genre": "Test", "releaseDate": "2024-01-01", "last_modified": "1700000000",
           "rating": "6.9", "rating_5based": 3.4, "backdrop_path": [],
           "youtube_trailer": "", "episode_run_time": "20", "category_id": "20"}]
EPISODES = {"episodes": {"1": [
    {"id": "9001", "episode_num": 1, "title": "Pilot", "container_extension": "mp4",
     "info": {"plot": "First episode"}, "season": 1},
    {"id": "9002", "episode_num": 2, "title": "Second", "container_extension": "mp4",
     "info": {"plot": "Second episode"}, "season": 1},
]}}


def b64(text):
    import base64
    return base64.b64encode(text.encode()).decode()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("mock-panel: " + fmt % args + "\n")

    def _json(self, payload, status=200):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _bytes(self, data, ctype):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        if u.path.endswith("/player_api.php"):
            user = (q.get("username") or [""])[0]
            pw = (q.get("password") or [""])[0]
            action = (q.get("action") or [""])[0]
            if action:
                if not OPEN and (user != VALID["username"] or pw != VALID["password"]):
                    return self._json({"user_info": {"auth": 0}}, status=200)
                cat = (q.get("category_id") or [""])[0]
                if action == "get_live_categories":
                    return self._json(LIVE_CATS)
                if action == "get_live_streams":
                    return self._json([s for s in LIVE if not cat or s["category_id"] == cat])
                if action == "get_vod_categories":
                    return self._json(VOD_CATS)
                if action == "get_vod_streams":
                    return self._json([s for s in VOD if not cat or s["category_id"] == cat])
                if action == "get_series_categories":
                    return self._json(SERIES_CATS)
                if action == "get_series":
                    return self._json([s for s in SERIES if not cat or s["category_id"] == cat])
                if action == "get_series_info":
                    return self._json(EPISODES)
                if action == "get_short_epg":
                    return self._json({"epg_listings": [
                        {"id": "1", "epg_id": "1", "title": b64("Synthetic News Hour"),
                         "lang": "en", "start": "2026-09-19 18:00:00", "end": "2026-09-19 19:00:00",
                         "description": b64("Generated for offline testing."),
                         "channel_id": "tp1", "start_timestamp": "1784563200",
                         "stop_timestamp": "1784566800"},
                        {"id": "2", "epg_id": "1", "title": b64("Synthetic Talk Show"),
                         "lang": "en", "start": "2026-09-19 19:00:00", "end": "2026-09-19 20:00:00",
                         "description": b64("Generated for offline testing."),
                         "channel_id": "tp1", "start_timestamp": "1784566800",
                         "stop_timestamp": "1784570400"}]})
                return self._json({})
            return self._json({
                "user_info": {
                    "username": user, "password": pw, "message": "Welcome",
                    "auth": 1 if (user == VALID["username"] and pw == VALID["password"]) else 0,
                    "status": "Active", "exp_date": "1790000000", "is_trial": "0",
                    "active_cons": "1", "created_at": "1700000000", "max_connections": "2",
                    "allowed_output_formats": ["m3u8", "ts", "mp4"],
                },
                "server_info": {
                    "url": "127.0.0.1", "port": str(PORT), "https_port": "",
                    "server_protocol": "http", "rtmp_port": "", "timezone": "Europe/Berlin",
                    "timestamp_now": 1784563200, "time_now": "2026-09-19 18:00:00",
                },
            })
        if u.path.endswith("/get.php"):
            m3u = ("#EXTM3U\n"
                   '#EXTINF:-1 tvg-id="tp1" group-title="News",Test Pattern One HD\n'
                   f"http://127.0.0.1:{PORT}/live/{VALID['username']}/{VALID['password']}/101.ts\n"
                   '#EXTINF:-1 tvg-id="tp2" group-title="News",Test Pattern Two\n'
                   f"http://127.0.0.1:{PORT}/live/{VALID['username']}/{VALID['password']}/102.ts\n")
            return self._bytes(m3u.encode(), "application/vnd.apple.mpegurl")
        if u.path.endswith("/xmltv.php"):
            xml = ('<?xml version="1.0"?><tv><channel id="tp1"><display-name>Test One</display-name>'
                   '</channel><programme start="20260919180000 +0200" stop="20260919190000 +0200" '
                   'channel="tp1"><title>Synthetic News Hour</title></programme></tv>')
            return self._bytes(xml.encode(), "application/xml")
        if u.path.startswith("/live/") or u.path.startswith("/movie/") or u.path.startswith("/series/"):
            with open(CLIP, "rb") as fh:
                return self._bytes(fh.read(), "video/mp4")
        self.send_response(404)
        self.send_header("Content-Length", "0")
        self.end_headers()


if __name__ == "__main__":
    print(f"mock Xtream panel on http://127.0.0.1:{PORT}  user=demo pass=demo")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()