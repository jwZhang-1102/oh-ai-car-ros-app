#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""危险区域配置加载与点在多边形内判断（map 坐标系）。"""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Sequence, Tuple


@dataclass(frozen=True)
class DangerZone:
    name: str
    points: Tuple[Tuple[float, float], ...]


def load_danger_zones(path: Path) -> Tuple[str, List[DangerZone]]:
    """加载 danger_zones.json，返回 (frame_id, zones)。"""
    data = json.loads(path.read_text(encoding="utf-8"))
    frame = str(data.get("frame", "map"))
    zones: List[DangerZone] = []
    for item in data.get("zones", []):
        name = str(item.get("name", "zone"))
        raw_pts = item.get("points", [])
        pts = tuple((float(p[0]), float(p[1])) for p in raw_pts)
        if len(pts) >= 3:
            zones.append(DangerZone(name=name, points=pts))
    return frame, zones


def point_in_polygon(x: float, y: float, polygon: Sequence[Tuple[float, float]]) -> bool:
    """Ray casting：判断 (x,y) 是否在多边形内（含边界）。"""
    n = len(polygon)
    if n < 3:
        return False

    inside = False
    j = n - 1
    for i in range(n):
        xi, yi = polygon[i]
        xj, yj = polygon[j]
        if _point_on_segment(x, y, xi, yi, xj, yj):
            return True
        intersects = (yi > y) != (yj > y)
        if intersects:
            x_cross = (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi
            if x <= x_cross:
                inside = not inside
        j = i
    return inside


def _point_on_segment(
    px: float, py: float,
    x1: float, y1: float,
    x2: float, y2: float,
    eps: float = 1e-6,
) -> bool:
    cross = (px - x1) * (y2 - y1) - (py - y1) * (x2 - x1)
    if abs(cross) > eps:
        return False
    dot = (px - x1) * (px - x2) + (py - y1) * (py - y2)
    return dot <= eps


def find_zone_at(x: float, y: float, zones: Sequence[DangerZone]) -> Optional[DangerZone]:
    for zone in zones:
        if point_in_polygon(x, y, zone.points):
            return zone
    return None
