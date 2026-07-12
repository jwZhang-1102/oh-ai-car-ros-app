#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智检哨兵 Day2：HTTP 服务，供 App 拉取事件列表与截图。

用法:
  cd ~/Rosmaster-App/rosmaster
  pip3 install flask --user
  python3 patrol_server.py

接口:
  GET http://<jetson_ip>:6700/events
  GET http://<jetson_ip>:6700/snapshot/<filename>
"""
from __future__ import annotations

import json
from pathlib import Path

from flask import Flask, jsonify, send_from_directory

WORK_DIR = Path(__file__).resolve().parent
EVENTS_FILE = WORK_DIR / "events.jsonl"
PATROL_DIR = WORK_DIR / "capture" / "patrol"
PORT = 6700

app = Flask(__name__)


@app.route("/events")
def list_events():
    items = []
    if EVENTS_FILE.is_file():
        for line in EVENTS_FILE.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line:
                items.append(json.loads(line))
    items.reverse()
    return jsonify(items)


@app.route("/snapshot/<path:name>")
def get_snapshot(name: str):
    return send_from_directory(str(PATROL_DIR), name)


@app.route("/health")
def health():
    return jsonify({
        "status": "ok",
        "events_file": str(EVENTS_FILE),
        "patrol_dir": str(PATROL_DIR),
    })


if __name__ == "__main__":
    PATROL_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Patrol server: http://0.0.0.0:{PORT}")
    print("  GET /events")
    print("  GET /snapshot/<filename>")
    app.run(host="0.0.0.0", port=PORT, threaded=True)
