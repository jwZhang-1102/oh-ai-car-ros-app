#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智检哨兵：YOLO 检测 person/bottle 等 → 截图 + events.jsonl
危险区联动：读 map 位姿 + person 在危险多边形内 → 蜂鸣器报警

用法:
  cd ~/Rosmaster-App/rosmaster
  python3 patrol_detector.py
  python3 patrol_detector.py --display          # 前台带窗口，便于调试
  python3 patrol_detector.py --conf 0.35 --min-frames 3
  python3 patrol_detector.py --zones danger_zones.json --buzzer-ms 500

输出:
  - 终端/日志: [ALERT] / [DANGER] 行（触发时）
  - events.jsonl: 每行一条 JSON
  - capture/patrol/*.jpg: 截图
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

import cv2
import numpy as np
import torch

from danger_zone_utils import DangerZone, find_zone_at, load_danger_zones
from pose_reader import AmclPoseReader, MapPose, fetch_docker_pose_once
from rosmaster_buzzer import BuzzerController

YOLO_ROOT = Path("/home/jetson/yolov5-7.0")
WORK_DIR = Path(__file__).resolve().parent
PATROL_DIR = WORK_DIR / "capture" / "patrol"
EVENTS_FILE = WORK_DIR / "events.jsonl"
DEFAULT_ZONES_FILE = WORK_DIR / "danger_zones.json"

DEFAULT_TARGETS = {"person", "bottle", "backpack", "chair"}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="智检哨兵 YOLO 巡检检测")
    p.add_argument("--weights", default=str(WORK_DIR / "yolov5s.pt"))
    p.add_argument("--source", type=int, default=0, help="摄像头索引，默认 video0")
    p.add_argument("--device", default="cuda", choices=["cuda", "cpu"])
    p.add_argument("--size", type=int, default=320, help="推理输入边长")
    p.add_argument("--conf", type=float, default=0.45, help="置信度阈值")
    p.add_argument("--min-frames", type=int, default=5, help="连续 N 帧才告警")
    p.add_argument("--cooldown", type=float, default=8.0, help="同类告警冷却秒数")
    p.add_argument(
        "--targets",
        default="person,bottle,backpack,chair",
        help="逗号分隔 COCO 类名，如 person,bottle",
    )
    p.add_argument("--display", action="store_true",
                   help="显示带 YOLO 检测框的窗口（绿框=targets 内类别）")
    p.add_argument("--verbose", action="store_true", help="每 30 帧打印一次心跳")
    p.add_argument(
        "--zones",
        default=str(DEFAULT_ZONES_FILE),
        help="危险区 JSON；不存在则关闭危险区联动",
    )
    p.add_argument(
        "--no-zones",
        action="store_true",
        help="禁用危险区判断与蜂鸣（仅 YOLO 告警）",
    )
    p.add_argument(
        "--danger-class",
        default="person",
        help="触发危险区蜂鸣的目标类别，默认 person",
    )
    p.add_argument(
        "--buzzer-ms",
        type=int,
        default=500,
        help="蜂鸣时长（毫秒），对应 Rosmaster set_beep",
    )
    p.add_argument(
        "--no-buzzer",
        action="store_true",
        help="禁用蜂鸣器（仍记录事件）",
    )
    p.add_argument(
        "--buzzer-tcp-only",
        action="store_true",
        help="蜂鸣仅走 TCP，不打开 Rosmaster 串口",
    )
    p.add_argument(
        "--buzzer-serial",
        action="store_true",
        help="蜂鸣走 Rosmaster 串口（仅巡检单机模式；与 Docker 导航不可并行）",
    )
    p.add_argument(
        "--docker-nav",
        action="store_true",
        help="与 Docker 导航并行：不占串口、位姿走 docker、降低轮询频率",
    )
    p.add_argument(
        "--nav-lite",
        action="store_true",
        help="导航并行轻量模式：CPU 推理 + 小分辨率，减轻 Jetson 负载",
    )
    p.add_argument(
        "--pose-backend",
        default="auto",
        choices=["auto", "rclpy", "docker"],
        help="位姿来源：auto=先 rclpy 再 docker exec",
    )
    p.add_argument(
        "--docker-container",
        default="",
        help="导航容器 ID（默认自动 docker ps 检测）",
    )
    p.add_argument(
        "--pose-topic",
        default="/amcl_pose",
        help="map 位姿话题，Docker 导航默认 /amcl_pose",
    )
    p.add_argument(
        "--skip-pose",
        action="store_true",
        help="完全不读位姿（危险区坐标判断关闭）",
    )
    p.add_argument(
        "--pose-on-demand",
        action="store_true",
        help="仅告警时读一次位姿（与 Docker 导航并行，推荐）",
    )
    p.add_argument(
        "--pose-poll-background",
        action="store_true",
        help="后台持续轮询位姿（与导航并行可能冲突，勿用）",
    )
    p.add_argument(
        "--pose-stale",
        type=float,
        default=3.0,
        help="位姿超过 N 秒未更新视为无效",
    )
    p.add_argument(
        "--pose-poll",
        type=float,
        default=0.5,
        help="docker 位姿轮询间隔（秒）；与导航并行建议 >=2",
    )
    p.add_argument(
        "--tcp-host",
        default="127.0.0.1",
        help="蜂鸣 TCP 回退地址（cmd=13）",
    )
    p.add_argument("--tcp-port", type=int, default=6000, help="蜂鸣 TCP 端口")
    return p.parse_args()


def load_model(weights: str, device_name: str):
    if not YOLO_ROOT.is_dir():
        raise RuntimeError(f"找不到 YOLO 目录: {YOLO_ROOT}")
    sys.path.insert(0, str(YOLO_ROOT))
    from models.common import DetectMultiBackend
    from utils.general import non_max_suppression, scale_boxes
    from utils.augmentations import letterbox

    device = torch.device("cuda:0" if device_name == "cuda" and torch.cuda.is_available() else "cpu")
    model = DetectMultiBackend(weights, device=device, fp16=False)
    stride = int(model.stride)
    names = model.names
    return model, device, stride, names, non_max_suppression, scale_boxes, letterbox


def open_camera(source: int) -> cv2.VideoCapture:
    cap = cv2.VideoCapture(source)
    if not cap.isOpened():
        raise RuntimeError(f"无法打开摄像头 video{source}")
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    return cap


def infer_frame(model, device, stride, names, nms_fn, scale_fn, letterbox_fn, frame, imgsz, conf_thres):
    im0 = frame
    im_lb = letterbox_fn(im0, imgsz, stride=stride, auto=True)[0]
    im = im_lb.transpose((2, 0, 1))[::-1]
    im = np.ascontiguousarray(im)
    tensor = torch.from_numpy(im).to(device)
    tensor = tensor.float() / 255.0
    if tensor.ndimension() == 3:
        tensor = tensor.unsqueeze(0)

    pred = model(tensor)
    pred = nms_fn(pred, conf_thres, 0.45, None, False, max_det=50)[0]
    hits: List[Tuple[str, float, Tuple[int, int, int, int]]] = []
    if pred is None or len(pred) == 0:
        return hits

    pred[:, :4] = scale_fn(im_lb.shape[:2], pred[:, :4], im0.shape).round()
    for *box, conf, cls_id in pred.tolist():
        cls_name = names[int(cls_id)]
        x1, y1, x2, y2 = map(int, box)
        hits.append((cls_name, float(conf), (x1, y1, x2, y2)))
    return hits


def draw_detections(
    frame,
    hits: List[Tuple[str, float, Tuple[int, int, int, int]]],
    targets: Set[str],
) -> np.ndarray:
    """在画面上画 YOLO 检测框（--display 用）。"""
    vis = frame.copy()
    for cls_name, conf, (x1, y1, x2, y2) in hits:
        in_target = cls_name in targets
        color = (0, 255, 0) if in_target else (160, 160, 160)
        thickness = 2 if in_target else 1
        cv2.rectangle(vis, (x1, y1), (x2, y2), color, thickness)
        label = "{0} {1:.2f}".format(cls_name, conf)
        cv2.putText(
            vis, label, (x1, max(y1 - 6, 12)),
            cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1, cv2.LINE_AA,
        )
    return vis


def save_event(
    frame,
    cls_name: str,
    conf: float,
    pose: Optional[MapPose] = None,
    zone: Optional[DangerZone] = None,
    buzzer: bool = False,
) -> None:
    PATROL_DIR.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    shot_name = f"{ts}_{cls_name}.jpg"
    shot_path = PATROL_DIR / shot_name
    cv2.imwrite(str(shot_path), frame)

    event: Dict[str, object] = {
        "id": f"{ts}_{cls_name}",
        "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "class": cls_name,
        "confidence": round(conf, 3),
        "snapshot": shot_name,
    }
    if pose is not None:
        event["pose"] = {
            "x": round(pose.x, 3),
            "y": round(pose.y, 3),
            "yaw": round(pose.yaw, 3),
        }
    if zone is not None:
        event["danger_zone"] = zone.name
        event["buzzer"] = buzzer

    with EVENTS_FILE.open("a", encoding="utf-8") as f:
        f.write(json.dumps(event, ensure_ascii=False) + "\n")

    tag = "[DANGER]" if buzzer else "[ALERT]"
    zone_txt = f" zone={zone.name}" if zone else ""
    pose_txt = ""
    if pose is not None:
        pose_txt = f" pose=({pose.x:.2f},{pose.y:.2f})"
    msg = (
        f"{tag} {event['time']} class={cls_name} conf={conf:.2f}"
        f"{zone_txt}{pose_txt} snapshot={shot_name}"
    )
    print(msg, flush=True)


def main() -> None:
    args = parse_args()
    if args.nav_lite:
        args.docker_nav = True
        args.device = "cpu"
        args.size = min(args.size, 256)
        if args.pose_poll < 3.0:
            args.pose_poll = 3.0
    if args.docker_nav:
        if args.pose_backend == "auto":
            args.pose_backend = "docker"
        if not args.skip_pose and not args.pose_poll_background:
            args.pose_on_demand = True
        if args.pose_poll_background and args.pose_poll < 2.0:
            args.pose_poll = 2.0
        if args.buzzer_serial:
            print(
                "[patrol_detector] WARN: --docker-nav 与 --buzzer-serial 冲突，"
                "已忽略 --buzzer-serial",
                flush=True,
            )
            args.buzzer_serial = False

    targets: Set[str] = {t.strip() for t in args.targets.split(",") if t.strip()}
    danger_class = args.danger_class.strip()

    zones: List[DangerZone] = []
    zones_enabled = not args.no_zones
    if zones_enabled:
        zones_path = Path(args.zones)
        if zones_path.is_file():
            frame_id, zones = load_danger_zones(zones_path)
            print(
                f"[patrol_detector] danger_zones={len(zones)} frame={frame_id} "
                f"file={zones_path}",
                flush=True,
            )
        else:
            zones_enabled = False
            print(
                f"[patrol_detector] WARN: 未找到危险区文件 {zones_path}，关闭危险区联动",
                flush=True,
            )

    pose_reader: Optional[AmclPoseReader] = None
    pose_on_demand = zones_enabled and args.pose_on_demand and not args.skip_pose
    use_pose_background = (
        zones_enabled and not args.skip_pose and not args.pose_on_demand
    )
    docker_cid = args.docker_container.strip() or None

    if use_pose_background:
        pose_reader = AmclPoseReader(
            topic=args.pose_topic,
            stale_sec=args.pose_stale,
            backend=args.pose_backend,
            docker_container=docker_cid,
            poll_sec=args.pose_poll,
        )
        pose_reader.start()
        print(
            f"[patrol_detector] 位姿 backend={args.pose_backend} "
            f"topic={args.pose_topic} poll={args.pose_poll}s（后台轮询）",
            flush=True,
        )
    elif pose_on_demand:
        print(
            f"[patrol_detector] 位姿 on-demand：仅告警时读 {args.pose_topic}，"
            "不干扰导航",
            flush=True,
        )

    buzzer: Optional[BuzzerController] = None
    if zones_enabled and not args.no_buzzer:
        prefer_lib = args.buzzer_serial and not (
            args.buzzer_tcp_only or args.docker_nav
        )
        buzzer = BuzzerController(
            tcp_host=args.tcp_host,
            tcp_port=args.tcp_port,
            prefer_lib=prefer_lib,
        )
        if prefer_lib and buzzer.available:
            src = "Rosmaster_Lib"
        elif prefer_lib:
            src = "TCP {0}:{1}（串口留给 Docker 导航）".format(
                args.tcp_host, args.tcp_port)
        else:
            src = "TCP-only {0}:{1}（Docker 并行模式，未占串口）".format(
                args.tcp_host, args.tcp_port)
        print(
            f"[patrol_detector] 蜂鸣器 backend={src} duration={args.buzzer_ms}ms",
            flush=True,
        )
    if args.docker_nav:
        print(
            "[patrol_detector] Docker 并行模式：不占底盘串口，勿开宿主机 ros/run",
            flush=True,
        )
    if args.skip_pose and zones_enabled:
        print(
            "[patrol_detector] skip-pose：危险区坐标判断关闭",
            flush=True,
        )
    if args.nav_lite:
        print(
            f"[patrol_detector] nav-lite: device={args.device} size={args.size}",
            flush=True,
        )

    print(
        f"[patrol_detector] targets={sorted(targets)} conf={args.conf} "
        f"min_frames={args.min_frames} cooldown={args.cooldown}s",
        flush=True,
    )
    print(f"[patrol_detector] weights={args.weights} source=video{args.source}", flush=True)

    model, device, stride, names, nms_fn, scale_fn, letterbox_fn = load_model(
        args.weights, args.device
    )
    cap = open_camera(args.source)
    print(f"[patrol_detector] camera OK, device={device}", flush=True)

    streak: Dict[str, int] = {}
    last_alert: Dict[str, float] = {}
    frame_idx = 0
    pose_warned = False
    buzzer_warned = False

    try:
        while True:
            ok, frame = cap.read()
            if not ok or frame is None:
                print("[patrol_detector] WARN: 读帧失败", flush=True)
                time.sleep(0.2)
                continue

            frame_idx += 1
            hits = infer_frame(
                model, device, stride, names, nms_fn, scale_fn, letterbox_fn,
                frame, args.size, args.conf,
            )

            pose = pose_reader.get_pose() if pose_reader else None
            if pose_reader and pose_reader.backend_name and frame_idx == 1:
                print(
                    f"[patrol_detector] 位姿通道: {pose_reader.backend_name}",
                    flush=True,
                )
            if pose_reader and not pose_reader.ready and pose_reader.error and not pose_warned:
                print(f"[patrol_detector] WARN: {pose_reader.error}", flush=True)
                pose_warned = True
            elif pose_reader and pose_reader.ready and pose is None and not pose_warned:
                print(
                    "[patrol_detector] WARN: 暂无有效位姿（RViz 2D Pose Estimate 或等待 AMCL）",
                    flush=True,
                )
                pose_warned = True

            seen_this_frame: Set[str] = set()
            for cls_name, conf, _box in hits:
                if cls_name not in targets:
                    continue
                seen_this_frame.add(cls_name)
                streak[cls_name] = streak.get(cls_name, 0) + 1
                if streak[cls_name] >= args.min_frames:
                    now = time.time()
                    if now - last_alert.get(cls_name, 0) >= args.cooldown:
                        zone: Optional[DangerZone] = None
                        trigger_buzzer = False
                        alert_pose: Optional[MapPose] = pose

                        if zones_enabled and cls_name == danger_class and zones:
                            if pose_on_demand:
                                alert_pose = fetch_docker_pose_once(
                                    args.pose_topic, docker_cid,
                                )
                            if alert_pose is not None:
                                zone = find_zone_at(
                                    alert_pose.x, alert_pose.y, zones,
                                )
                                if zone is not None and buzzer is not None:
                                    trigger_buzzer = buzzer.beep(args.buzzer_ms)
                                    if not trigger_buzzer and not buzzer_warned:
                                        print(
                                            "[patrol_detector] WARN: 蜂鸣器触发失败"
                                            "（并行导航时蜂鸣可能不可用）",
                                            flush=True,
                                        )
                                        buzzer_warned = True
                            elif pose_on_demand and not pose_warned:
                                print(
                                    "[patrol_detector] WARN: on-demand 位姿读取失败"
                                    "（容器 n1 + 2D Pose Estimate？）",
                                    flush=True,
                                )
                                pose_warned = True

                        save_event(
                            frame, cls_name, conf,
                            pose=alert_pose, zone=zone, buzzer=trigger_buzzer,
                        )
                        last_alert[cls_name] = now
                        streak[cls_name] = 0

            for cls_name in list(streak.keys()):
                if cls_name not in seen_this_frame:
                    streak[cls_name] = 0

            if args.verbose and frame_idx % 30 == 0:
                top = [(n, c) for n, c, _ in hits[:3]]
                pose_hint = ""
                if pose is not None:
                    zname = ""
                    if zones:
                        z = find_zone_at(pose.x, pose.y, zones)
                        zname = f" zone={z.name}" if z else ""
                    pose_hint = f" pose=({pose.x:.1f},{pose.y:.1f}){zname}"
                print(
                    f"[patrol_detector] frame={frame_idx} hits={top}{pose_hint}",
                    flush=True,
                )

            if args.display:
                vis = draw_detections(frame, hits, targets)
                cv2.imshow("patrol_detector", vis)
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break
    finally:
        cap.release()
        if pose_reader is not None:
            pose_reader.stop()
        if args.display:
            cv2.destroyAllWindows()
        print("[patrol_detector] stopped", flush=True)


if __name__ == "__main__":
    main()
