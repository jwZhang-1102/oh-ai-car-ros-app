#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""激光雷达点云 → map 坐标变换、聚类、人体尺度过滤。"""
from __future__ import annotations

import math
import re
import subprocess
from dataclasses import dataclass
from typing import List, Optional, Sequence, Tuple

from pose_reader import MapPose, find_nav_container

Point2D = Tuple[float, float]


@dataclass(frozen=True)
class LaserScan:
    angle_min: float
    angle_increment: float
    range_min: float
    range_max: float
    ranges: Tuple[float, ...]


@dataclass(frozen=True)
class MapCluster:
    points: Tuple[Point2D, ...]
    centroid: Point2D
    span: float


def _parse_float_list(block: str) -> List[float]:
    values: List[float] = []
    for line in block.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("- "):
            line = line[2:].strip()
        for token in line.replace(",", " ").split():
            try:
                values.append(float(token))
            except ValueError:
                continue
    return values


def parse_laser_scan_echo(text: str) -> Optional[LaserScan]:
    """解析 `ros2 topic echo /scan --once` 的 YAML 文本。"""
    if not text.strip():
        return None

    def _field(name: str, default: Optional[float] = None) -> Optional[float]:
        m = re.search(rf"^{name}:\s*([-\d.eE+]+)\s*$", text, re.M)
        if m:
            return float(m.group(1))
        return default

    angle_min = _field("angle_min")
    angle_increment = _field("angle_increment")
    range_min = _field("range_min", 0.05)
    range_max = _field("range_max", 30.0)
    if angle_min is None or angle_increment is None:
        return None

    ranges_block = re.search(r"^ranges:\s*$([\s\S]*)", text, re.M)
    if not ranges_block:
        inline = re.search(r"^ranges:\s*\[(.*?)\]", text, re.M | re.S)
        if inline:
            raw = inline.group(1).replace("\n", " ")
            vals = []
            for tok in raw.split(","):
                tok = tok.strip()
                if not tok:
                    continue
                try:
                    vals.append(float(tok))
                except ValueError:
                    vals.append(float("inf"))
            ranges = tuple(vals)
        else:
            return None
    else:
        tail = ranges_block.group(1)
        stop = re.search(
            r"^\w[\w_]*:\s",
            tail,
            re.M,
        )
        if stop:
            tail = tail[:stop.start()]
        ranges = tuple(_parse_float_list(tail))

    if not ranges:
        return None

    return LaserScan(
        angle_min=angle_min,
        angle_increment=angle_increment,
        range_min=range_min or 0.05,
        range_max=range_max or 30.0,
        ranges=ranges,
    )


def fetch_docker_scan_once(
    topic: str = "/scan",
    docker_container: Optional[str] = None,
) -> Optional[LaserScan]:
    """从导航容器读取一帧 LaserScan。"""
    cid = find_nav_container(docker_container)
    if not cid:
        return None
    cmd = [
        "docker", "exec", cid,
        "bash", "-lc",
        f"timeout 5 ros2 topic echo {topic} --once 2>/dev/null",
    ]
    try:
        out = subprocess.check_output(
            cmd, text=True, timeout=12, stderr=subprocess.DEVNULL,
        )
        return parse_laser_scan_echo(out)
    except Exception:
        return None


def laser_points_in_map(
    scan: LaserScan,
    pose: MapPose,
    *,
    laser_offset_x: float = 0.0,
    laser_offset_y: float = 0.0,
    min_range: float = 0.4,
    max_range: float = 8.0,
    ray_stride: int = 1,
) -> List[Point2D]:
    """将有效激光点变换到 map 坐标系。"""
    points: List[Point2D] = []
    cos_y = math.cos(pose.yaw)
    sin_y = math.sin(pose.yaw)

    for i in range(0, len(scan.ranges), max(1, ray_stride)):
        dist = scan.ranges[i]
        if not math.isfinite(dist):
            continue
        if dist < max(scan.range_min, min_range) or dist > min(scan.range_max, max_range):
            continue

        angle = scan.angle_min + i * scan.angle_increment
        lx = dist * math.cos(angle) + laser_offset_x
        ly = dist * math.sin(angle) + laser_offset_y

        mx = pose.x + cos_y * lx - sin_y * ly
        my = pose.y + sin_y * lx + cos_y * ly
        points.append((mx, my))

    return points


def _dist2(a: Point2D, b: Point2D) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def cluster_points(
    points: Sequence[Point2D],
    *,
    eps: float = 0.18,
    min_points: int = 2,
) -> List[MapCluster]:
    """简单距离聚类（适合少量激光点）。"""
    if not points:
        return []

    pts = list(points)
    used = [False] * len(pts)
    clusters: List[MapCluster] = []

    for i, seed in enumerate(pts):
        if used[i]:
            continue
        group = [seed]
        used[i] = True
        queue = [seed]
        while queue:
            cur = queue.pop()
            for j, other in enumerate(pts):
                if used[j]:
                    continue
                if _dist2(cur, other) <= eps:
                    used[j] = True
                    group.append(other)
                    queue.append(other)
        if len(group) < min_points:
            continue
        cx = sum(p[0] for p in group) / len(group)
        cy = sum(p[1] for p in group) / len(group)
        span = 0.0
        for a in group:
            for b in group:
                span = max(span, _dist2(a, b))
        clusters.append(
            MapCluster(
                points=tuple(group),
                centroid=(cx, cy),
                span=span,
            )
        )
    return clusters


def filter_person_like_clusters(
    clusters: Sequence[MapCluster],
    *,
    min_span: float = 0.12,
    max_span: float = 0.85,
    min_points: int = 2,
    max_points: int = 40,
) -> List[MapCluster]:
    """按人体在激光下的近似尺寸过滤团块（腿/躯干投影）。"""
    result: List[MapCluster] = []
    for c in clusters:
        n = len(c.points)
        if n < min_points or n > max_points:
            continue
        if c.span < min_span or c.span > max_span:
            continue
        result.append(c)
    return result
