#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
低延迟 MJPEG 推流（G29 模拟驾驶专用）

- 摄像头缓冲设为 1，采集线程持续丢旧帧，只保留最新 JPEG
- 标准 multipart/x-mixed-replace; boundary=frame（兼容 ffplay / VLC / 浏览器）

用法（Jetson，需先停 Yahboom 6500 摄像头服务）:
  bash stop_camera_server.sh 2>/dev/null || true
  bash stop_patrol_host.sh 2>/dev/null || true
  v4l2-ctl -d /dev/video0 --set-fmt-video=width=320,height=240,pixelformat=MJPG
  python3 low_latency_mjpeg.py --port 6501

PC:
  ffplay -f mpjpeg -fflags nobuffer -flags low_delay -framedrop http://10.147.13.194:6501/video_feed
"""
from __future__ import annotations

import argparse
import subprocess
import threading
import time
from typing import Optional

import cv2
from flask import Flask, Response, jsonify

app = Flask(__name__)

_latest_jpeg: Optional[bytes] = None
_latest_lock = threading.Lock()
_capture_running = False
_stats = {"frames": 0, "errors": 0, "last_ts": 0.0}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="低延迟 MJPEG HTTP 推流")
    p.add_argument("--device", type=int, default=0, help="摄像头索引，默认 video0")
    p.add_argument("--width", type=int, default=320)
    p.add_argument("--height", type=int, default=240)
    p.add_argument("--fps", type=int, default=15, help="推流上限帧率")
    p.add_argument("--quality", type=int, default=60, help="JPEG 质量 1-100")
    p.add_argument("--port", type=int, default=6501, help="HTTP 端口，默认 6501 避免与 Yahboom 6500 冲突")
    p.add_argument("--drain", type=int, default=8, help="每轮最多丢弃多少帧积压")
    p.add_argument(
        "--v4l2-setup",
        action="store_true",
        help="启动前用 v4l2-ctl 强制 MJPG 格式（需已安装 v4l-utils）",
    )
    return p.parse_args()


def v4l2_setup(device: int, width: int, height: int, fps: int) -> None:
    dev = f"/dev/video{device}"
    cmds = [
        [
            "v4l2-ctl", "-d", dev,
            f"--set-fmt-video=width={width},height={height},pixelformat=MJPG",
        ],
        ["v4l2-ctl", "-d", dev, "--set-parm", str(fps)],
    ]
    for cmd in cmds:
        try:
            subprocess.run(cmd, check=False, capture_output=True, text=True)
        except FileNotFoundError:
            print("[low_latency] WARN: 未找到 v4l2-ctl，跳过 --v4l2-setup")
            return
    print(f"[low_latency] v4l2: {dev} MJPG {width}x{height} @{fps}fps")


def open_camera(device: int, width: int, height: int, fps: int) -> cv2.VideoCapture:
    dev_path = f"/dev/video{device}"
    last_err = "未知错误"
    for attempt in range(15):
        cap = cv2.VideoCapture(dev_path, cv2.CAP_V4L2)
        if not cap.isOpened():
            last_err = f"打不开 {dev_path}"
            time.sleep(0.5)
            continue

        cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        cap.set(cv2.CAP_PROP_FPS, fps)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

        ok, frame = cap.read()
        if ok and frame is not None:
            h, w = frame.shape[:2]
            print(
                f"[low_latency] camera OK {dev_path} actual={w}x{h}",
                flush=True,
            )
            return cap

        cap.release()
        last_err = f"{dev_path} 能打开但读帧失败"
        time.sleep(0.5)

    raise RuntimeError(
        f"无法打开摄像头 {dev_path}（{last_err}）\n"
        "请先释放摄像头：\n"
        "  1) 另终端 Ctrl+C 停 ros/run\n"
        "  2) bash stop_camera_server.sh && bash stop_patrol_host.sh\n"
        "  3) fuser -v /dev/video0   # 查看谁占用\n"
        "  4) 再 bash start_low_latency_video.sh\n"
        "6501 起来后再 ros/run（G29 需要 6000）"
    )


def capture_loop(cap: cv2.VideoCapture, quality: int, drain: int) -> None:
    global _latest_jpeg, _capture_running, _stats
    encode_params = [int(cv2.IMWRITE_JPEG_QUALITY), quality]

    while _capture_running:
        frame = None
        for _ in range(max(1, drain)):
            if not cap.grab():
                break
        ok, frame = cap.retrieve()
        if not ok or frame is None:
            _stats["errors"] += 1
            time.sleep(0.02)
            continue

        ok, buf = cv2.imencode(".jpg", frame, encode_params)
        if not ok:
            _stats["errors"] += 1
            continue

        data = buf.tobytes()
        with _latest_lock:
            _latest_jpeg = data
        _stats["frames"] += 1
        _stats["last_ts"] = time.time()


def mjpeg_stream(fps: int):
    interval = 1.0 / max(1, fps)
    boundary = b"--frame\r\n"
    header = b"Content-Type: image/jpeg\r\n\r\n"

    while True:
        t0 = time.time()
        with _latest_lock:
            jpg = _latest_jpeg
        if jpg:
            yield boundary + header + jpg + b"\r\n"
        elapsed = time.time() - t0
        sleep_s = interval - elapsed
        if sleep_s > 0:
            time.sleep(sleep_s)


@app.route("/video_feed")
def video_feed():
    return Response(
        mjpeg_stream(app.config["FPS"]),
        mimetype="multipart/x-mixed-replace; boundary=frame",
    )


@app.route("/")
@app.route("/index2")
def index_page():
    return (
        "<!DOCTYPE html><html><head><meta charset='utf-8'>"
        "<title>低延迟第一人称</title>"
        "<style>body{margin:0;background:#000}"
        "img{width:100vw;height:100vh;object-fit:contain}</style></head>"
        "<body><img src='/video_feed' alt='video'></body></html>"
    )


@app.route("/health")
def health():
    with _latest_lock:
        has_frame = _latest_jpeg is not None
    return jsonify({
        "status": "ok",
        "has_frame": has_frame,
        "stats": _stats,
        "port": app.config["PORT"],
    })


def main() -> None:
    global _capture_running
    args = parse_args()

    if args.v4l2_setup:
        v4l2_setup(args.device, args.width, args.height, args.fps)

    cap = open_camera(args.device, args.width, args.height, args.fps)
    app.config["FPS"] = args.fps
    app.config["PORT"] = args.port

    _capture_running = True
    t = threading.Thread(target=capture_loop, args=(cap, args.quality, args.drain), daemon=True)
    t.start()

    print(
        f"[low_latency] http://0.0.0.0:{args.port}/video_feed "
        f"({args.width}x{args.height} @{args.fps}fps q={args.quality})",
        flush=True,
    )
    print("[low_latency] 浏览器: / 或 /index2", flush=True)

    try:
        app.run(host="0.0.0.0", port=args.port, threaded=True, use_reloader=False)
    finally:
        _capture_running = False
        cap.release()


if __name__ == "__main__":
    main()
