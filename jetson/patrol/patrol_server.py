#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智检哨兵 Day2：HTTP 服务，供 App 拉取事件列表与截图。
扩展：自主导航任务协调 API（告警停车 / 恢复 / 人工 teleop）。

用法:
  cd ~/Rosmaster-App/rosmaster
  pip3 install flask --user
  python3 patrol_server.py

接口:
  GET  http://<jetson_ip>:6700/events
  GET  http://<jetson_ip>:6700/snapshot/<filename>
  GET  http://<jetson_ip>:6700/mission/status
  POST http://<jetson_ip>:6700/mission/start
  POST http://<jetson_ip>:6700/mission/resume
  POST http://<jetson_ip>:6700/mission/alert      {"class":"bottle","event_id":"..."}
  POST http://<jetson_ip>:6700/mission/teleop    {"vx":0.2,"vy":0,"wz":0}
  POST http://<jetson_ip>:6700/mission/set_end   {"x":1.0,"y":2.0,"yaw":0}
"""
from __future__ import annotations

import json
from pathlib import Path

from flask import Flask, jsonify, request, send_from_directory

from nav_mission_coordinator import get_coordinator

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
    coord = get_coordinator()
    return jsonify({
        "status": "ok",
        "events_file": str(EVENTS_FILE),
        "patrol_dir": str(PATROL_DIR),
        "mission": coord.get_status(),
    })


@app.route("/mission/status", methods=["GET"])
def mission_status():
    return jsonify(get_coordinator().get_status())


@app.route("/mission/start", methods=["POST"])
def mission_start():
    return jsonify(get_coordinator().start_mission())


@app.route("/mission/resume", methods=["POST"])
def mission_resume():
    return jsonify(get_coordinator().resume())


@app.route("/mission/manual", methods=["POST"])
def mission_manual():
    return jsonify(get_coordinator().enter_manual())


@app.route("/mission/reload", methods=["POST"])
def mission_reload():
    return jsonify(get_coordinator().reload_waypoints())


@app.route("/mission/alert", methods=["POST"])
def mission_alert():
    data = request.get_json(silent=True) or {}
    cls_name = str(data.get("class", "unknown"))
    event_id = data.get("event_id")
    confidence = data.get("confidence")
    if confidence is not None:
        try:
            confidence = float(confidence)
        except (TypeError, ValueError):
            confidence = None
    return jsonify(get_coordinator().on_alert(cls_name, event_id, confidence))


@app.route("/mission/teleop", methods=["POST"])
def mission_teleop():
    data = request.get_json(silent=True) or {}
    try:
        vx = float(data.get("vx", 0))
        vy = float(data.get("vy", 0))
        wz = float(data.get("wz", 0))
        duration = float(data.get("duration", 0.5))
    except (TypeError, ValueError):
        return jsonify({"ok": False, "error": "vx/vy/wz/duration 需为数字"}), 400
    return jsonify(get_coordinator().teleop(vx, vy, wz, duration_sec=duration))


@app.route("/mission/stop", methods=["POST"])
def mission_stop_teleop():
    return jsonify(get_coordinator().stop_teleop())


@app.route("/mission/set_end", methods=["POST"])
def mission_set_end():
    data = request.get_json(silent=True) or {}
    try:
        x = float(data["x"])
        y = float(data["y"])
        yaw = float(data.get("yaw", 0))
    except (KeyError, TypeError, ValueError):
        return jsonify({"ok": False, "error": "需要 JSON: {x, y, yaw?}"}), 400
    return jsonify(get_coordinator().set_end_goal(x, y, yaw))


if __name__ == "__main__":
    PATROL_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Patrol server: http://0.0.0.0:{PORT}")
    print("  GET  /events")
    print("  GET  /snapshot/<filename>")
    print("  GET  /mission/status")
    print("  POST /mission/start | /mission/resume | /mission/alert | /mission/teleop")
    app.run(host="0.0.0.0", port=PORT, threaded=True)
