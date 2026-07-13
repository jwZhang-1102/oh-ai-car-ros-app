#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RViz 点完 2D Goal Pose 后，从 Docker 读取 /goal_pose 并写入 mission 终点。

用法（Jetson 宿主机，RViz 刚发 Goal 后立即执行）:
  cd ~/Rosmaster-App/rosmaster
  python3 capture_end_goal.py

  python3 capture_end_goal.py --wait 30    # 30 秒内等 Goal 出现
  python3 capture_end_goal.py --print-only # 只打印不写文件
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import List, Optional, Tuple

from pose_reader import _yaw_from_quaternion, find_nav_container

WORK_DIR = Path(__file__).resolve().parent
WAYPOINTS_FILE = WORK_DIR / "mission_waypoints.json"
GOAL_TOPICS = ("/goal_pose", "/move_base_simple/goal", "/goal")


def parse_goal_echo(text: str) -> Optional[Tuple[float, float, float]]:
    """解析 ros2 topic echo PoseStamped 的 position + orientation。"""
    pos = re.search(r"position:(.*?)(?:orientation:|covariance:)", text, re.S)
    ori = re.search(r"orientation:(.*?)(?:\n[a-z_]+:|\Z)", text, re.S)
    if not pos or not ori:
        return None

    def _f(block: str, key: str) -> Optional[float]:
        m = re.search(rf"{key}:\s*([-\d.eE+]+)", block)
        return float(m.group(1)) if m else None

    x = _f(pos.group(1), "x")
    y = _f(pos.group(1), "y")
    qx = _f(ori.group(1), "x") or 0.0
    qy = _f(ori.group(1), "y") or 0.0
    qz = _f(ori.group(1), "z")
    qw = _f(ori.group(1), "w")
    if x is None or y is None or qz is None or qw is None:
        return None
    yaw = _yaw_from_quaternion(qx, qy, qz, qw)
    return x, y, yaw


def fetch_goal_once(
    docker_container: Optional[str] = None,
    topics: Tuple[str, ...] = GOAL_TOPICS,
) -> Optional[Tuple[str, float, float, float]]:
    cid = find_nav_container(docker_container)
    if not cid:
        print("[capture_goal] 错误: 未找到 Docker 容器", flush=True)
        return None

    for topic in topics:
        cmd = [
            "docker", "exec", cid,
            "bash", "-lc",
            f"timeout 4 ros2 topic echo {topic} --once 2>/dev/null | head -40",
        ]
        try:
            out = subprocess.check_output(
                cmd, text=True, timeout=10, stderr=subprocess.DEVNULL,
            )
        except Exception:
            continue
        parsed = parse_goal_echo(out)
        if parsed is not None:
            x, y, yaw = parsed
            return topic, x, y, yaw
    return None


def post_set_end(host: str, port: int, x: float, y: float, yaw: float) -> dict:
    url = f"http://{host}:{port}/mission/set_end"
    body = json.dumps({"x": x, "y": y, "yaw": yaw}).encode("utf-8")
    req = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/json"}, method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.URLError as exc:
        return {"ok": False, "error": str(exc)}


def write_waypoints_file(x: float, y: float, yaw: float, frame_id: str = "map") -> None:
    data = {
        "frame_id": frame_id,
        "end": {"x": round(x, 4), "y": round(y, 4), "yaw": round(yaw, 4)},
        "note": "由 capture_end_goal.py 从 RViz Goal 抓取",
    }
    WAYPOINTS_FILE.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    p = argparse.ArgumentParser(description="抓取 RViz Goal 写入 mission 终点")
    p.add_argument("--wait", type=float, default=0.0,
                   help="等待 Goal 出现的秒数（RViz 点完后再跑可设 0）")
    p.add_argument("--poll", type=float, default=0.5, help="等待时轮询间隔")
    p.add_argument("--docker-container", default="", help="指定导航容器 ID")
    p.add_argument("--host", default="127.0.0.1", help="patrol_server 地址")
    p.add_argument("--port", type=int, default=6700)
    p.add_argument("--print-only", action="store_true", help="只打印坐标不写入")
    p.add_argument("--no-http", action="store_true",
                   help="只写 mission_waypoints.json，不调 HTTP")
    args = p.parse_args()

    cid = args.docker_container.strip() or None
    deadline = time.time() + max(0.0, args.wait)
    result: Optional[Tuple[str, float, float, float]] = None

    while result is None:
        result = fetch_goal_once(cid)
        if result is not None:
            break
        if time.time() >= deadline:
            print(
                "[capture_goal] 未读到 Goal。请先在 RViz 点 2D Goal Pose，"
                "或加 --wait 30 再点 Goal",
                flush=True,
            )
            sys.exit(1)
        print("[capture_goal] 等待 RViz Goal …", flush=True)
        time.sleep(args.poll)

    topic, x, y, yaw = result
    print(
        f"[capture_goal] topic={topic} end=({x:.4f}, {y:.4f}, yaw={yaw:.4f})",
        flush=True,
    )

    if args.print_only:
        print(json.dumps({"x": x, "y": y, "yaw": yaw}, indent=2))
        return

    write_waypoints_file(x, y, yaw)
    print(f"[capture_goal] 已写入 {WAYPOINTS_FILE}", flush=True)

    if not args.no_http:
        resp = post_set_end(args.host, args.port, x, y, yaw)
        if resp.get("ok"):
            print("[capture_goal] HTTP /mission/set_end OK", flush=True)
        else:
            print(
                f"[capture_goal] WARN: HTTP 失败 {resp}（JSON 已写入，resume 仍可用）",
                flush=True,
            )


if __name__ == "__main__":
    main()
