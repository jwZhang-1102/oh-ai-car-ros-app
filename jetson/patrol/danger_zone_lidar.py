#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
方案一：激光雷达 + 地图危险区 —— 检测「人体尺度障碍」是否落在危险多边形内。

与导航并行：只读 Docker 内 /scan 与 /amcl_pose，不占串口、不用摄像头/YOLO。

用法:
  cd ~/Rosmaster-App/rosmaster
  python3 danger_zone_lidar.py
  python3 danger_zone_lidar.py --poll 1.2 --verbose
  python3 danger_zone_lidar.py --zones danger_zones.json --bg   # 见 start_danger_lidar.sh

日志:
  [DANGER-LIDAR] 人在危险区（激光团块质心落在多边形内）
  [ALERT-LIDAR]  检出人体尺度团块，但不在危险区内（--verbose）
"""
from __future__ import annotations

import argparse
import json
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

from danger_zone_utils import DangerZone, find_zone_at, load_danger_zones
from lidar_scan_utils import (
    MapCluster,
    cluster_points,
    fetch_docker_scan_once,
    filter_person_like_clusters,
    laser_points_in_map,
)
from pose_reader import MapPose, fetch_docker_pose_once
from rosmaster_buzzer import BuzzerController

WORK_DIR = Path(__file__).resolve().parent
EVENTS_FILE = WORK_DIR / "events.jsonl"
DEFAULT_ZONES_FILE = WORK_DIR / "danger_zones.json"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="激光雷达危险区入侵检测（人在危险区）")
    p.add_argument("--zones", default=str(DEFAULT_ZONES_FILE), help="危险区 JSON")
    p.add_argument("--scan-topic", default="/scan", help="激光话题")
    p.add_argument("--pose-topic", default="/amcl_pose", help="位姿话题")
    p.add_argument("--docker-container", default="", help="导航容器 ID，默认自动检测")
    p.add_argument("--poll", type=float, default=1.0, help="扫描周期（秒）")
    p.add_argument("--min-hits", type=int, default=3, help="连续 N 次命中才告警")
    p.add_argument("--cooldown", type=float, default=8.0, help="同类告警冷却（秒）")
    p.add_argument("--buzzer-ms", type=int, default=500, help="蜂鸣时长（毫秒）")
    p.add_argument("--no-buzzer", action="store_true", help="仅日志/事件，不蜂鸣")
    p.add_argument("--ray-stride", type=int, default=2, help="激光点降采样步长")
    p.add_argument("--cluster-eps", type=float, default=0.18, help="聚类距离（米）")
    p.add_argument("--verbose", action="store_true", help="打印非危险区团块")
    return p.parse_args()


def save_lidar_event(
    zone: Optional[DangerZone],
    cluster: MapCluster,
    pose: MapPose,
    buzzer: bool,
) -> None:
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    event: Dict[str, object] = {
        "id": f"{ts}_intruder_lidar",
        "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "class": "intruder_lidar",
        "source": "lidar",
        "confidence": 1.0,
        "snapshot": "",
        "intruder": {
            "x": round(cluster.centroid[0], 3),
            "y": round(cluster.centroid[1], 3),
            "span_m": round(cluster.span, 3),
            "points": len(cluster.points),
        },
        "robot_pose": {
            "x": round(pose.x, 3),
            "y": round(pose.y, 3),
            "yaw": round(pose.yaw, 3),
        },
    }
    if zone is not None:
        event["danger_zone"] = zone.name
        event["buzzer"] = buzzer

    with EVENTS_FILE.open("a", encoding="utf-8") as f:
        f.write(json.dumps(event, ensure_ascii=False) + "\n")


def detect_intruders_in_zones(
    pose: MapPose,
    zones: List[DangerZone],
    *,
    scan_topic: str,
    docker_container: str,
    ray_stride: int,
    cluster_eps: float,
) -> List[Tuple[DangerZone, MapCluster]]:
    scan = fetch_docker_scan_once(scan_topic, docker_container or None)
    if scan is None:
        return []

    map_points = laser_points_in_map(scan, pose, ray_stride=ray_stride)
    clusters = cluster_points(map_points, eps=cluster_eps)
    person_like = filter_person_like_clusters(clusters)

    hits: List[Tuple[DangerZone, MapCluster]] = []
    seen: Set[str] = set()
    for cluster in person_like:
        zone = find_zone_at(cluster.centroid[0], cluster.centroid[1], zones)
        if zone is None:
            for px, py in cluster.points:
                zone = find_zone_at(px, py, zones)
                if zone is not None:
                    break
        if zone is None:
            continue
        key = f"{zone.name}:{round(cluster.centroid[0], 2)}:{round(cluster.centroid[1], 2)}"
        if key in seen:
            continue
        seen.add(key)
        hits.append((zone, cluster))
    return hits


def main() -> None:
    args = parse_args()
    zones_path = Path(args.zones)
    if not zones_path.is_file():
        print(f"[danger_zone_lidar] 错误: 未找到 {zones_path}", flush=True)
        raise SystemExit(1)

    frame_id, zones = load_danger_zones(zones_path)
    if not zones:
        print("[danger_zone_lidar] 错误: danger_zones.json 无有效多边形", flush=True)
        raise SystemExit(1)

    docker_cid = args.docker_container.strip() or None
    buzzer: Optional[BuzzerController] = None
    if not args.no_buzzer:
        buzzer = BuzzerController(prefer_lib=False)

    print(
        f"[danger_zone_lidar] 启动 frame={frame_id} zones={len(zones)} "
        f"poll={args.poll}s ray_stride={args.ray_stride}",
        flush=True,
    )
    print(
        "[danger_zone_lidar] 规则: 激光人体尺度团块落在危险多边形内 → [DANGER-LIDAR]",
        flush=True,
    )

    streak = 0
    last_alert = 0.0
    buzzer_warned = False

    try:
        while True:
            pose = fetch_docker_pose_once(args.pose_topic, docker_cid)
            if pose is None:
                print(
                    "[danger_zone_lidar] WARN: 无位姿（容器 n1 + RViz 2D Pose Estimate）",
                    flush=True,
                )
                streak = 0
                time.sleep(args.poll)
                continue

            hits = detect_intruders_in_zones(
                pose,
                zones,
                scan_topic=args.scan_topic,
                docker_container=args.docker_container,
                ray_stride=args.ray_stride,
                cluster_eps=args.cluster_eps,
            )

            if hits:
                streak += 1
                if args.verbose:
                    for zone, cluster in hits:
                        print(
                            f"[danger_zone_lidar] 候选 zone={zone.name} "
                            f"intruder=({cluster.centroid[0]:.2f},{cluster.centroid[1]:.2f}) "
                            f"span={cluster.span:.2f}m pts={len(cluster.points)}",
                            flush=True,
                        )
            else:
                streak = 0

            if streak >= args.min_hits:
                now = time.time()
                if now - last_alert >= args.cooldown:
                    zone, cluster = hits[0]
                    triggered = False
                    if buzzer is not None:
                        triggered = buzzer.beep(args.buzzer_ms)
                        if not triggered and not buzzer_warned:
                            print(
                                "[danger_zone_lidar] WARN: 蜂鸣失败（并行导航时常见）",
                                flush=True,
                            )
                            buzzer_warned = True

                    save_lidar_event(zone, cluster, pose, triggered)
                    print(
                        f"[DANGER-LIDAR] {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} "
                        f"zone={zone.name} "
                        f"intruder=({cluster.centroid[0]:.2f},{cluster.centroid[1]:.2f}) "
                        f"robot=({pose.x:.2f},{pose.y:.2f}) "
                        f"buzzer={'on' if triggered else 'off'}",
                        flush=True,
                    )
                    last_alert = now
                    streak = 0

            time.sleep(args.poll)
    except KeyboardInterrupt:
        print("[danger_zone_lidar] stopped", flush=True)


if __name__ == "__main__":
    main()
