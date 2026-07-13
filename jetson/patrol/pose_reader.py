#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 ROS2 /amcl_pose 读取小车在 map 下的位姿（后台线程）。

宿主机无 ros2 时，自动通过 docker exec 从导航容器拉取位姿。
"""
from __future__ import annotations

import math
import re
import subprocess
import threading
import time
from dataclasses import dataclass
from typing import Optional


@dataclass
class MapPose:
    x: float
    y: float
    yaw: float
    stamp: float


def _yaw_from_quaternion(x: float, y: float, z: float, w: float) -> float:
    siny_cosp = 2.0 * (w * z + x * y)
    cosy_cosp = 1.0 - 2.0 * (y * y + z * z)
    return math.atan2(siny_cosp, cosy_cosp)


def parse_amcl_echo(text: str) -> Optional[MapPose]:
    """解析 `ros2 topic echo /amcl_pose --once` 的 YAML 输出。"""
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
    return MapPose(
        x=x,
        y=y,
        yaw=_yaw_from_quaternion(qx, qy, qz, qw),
        stamp=time.time(),
    )


def find_nav_container(explicit: Optional[str] = None) -> Optional[str]:
    if explicit:
        return explicit.strip() or None

    def _run(args: list) -> Optional[str]:
        try:
            out = subprocess.check_output(
                args, text=True, timeout=5, stderr=subprocess.DEVNULL,
            )
        except Exception:
            return None
        lines = [ln.strip() for ln in out.splitlines() if ln.strip()]
        return lines[0] if lines else None

    # 优先 autodrive / yahboom 导航容器（避免 n1/n2/n3 多容器时误选）
    try:
        out = subprocess.check_output(
            ["docker", "ps", "--format", "{{.ID}} {{.Image}}"],
            text=True,
            timeout=5,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        out = ""

    preferred: list[str] = []
    fallback: list[str] = []
    for line in out.splitlines():
        parts = line.split(None, 1)
        if not parts:
            continue
        cid, image = parts[0], parts[1] if len(parts) > 1 else ""
        low = image.lower()
        if any(k in low for k in ("autodrive", "icar", "ros-foxy", "ros-humble", "yahboom")):
            preferred.append(cid)
        else:
            fallback.append(cid)
    if preferred:
        return preferred[0]
    if fallback:
        return fallback[0]

    cid = _run(["docker", "ps", "-q"])
    if cid:
        return cid.split()[0]
    return None


def fetch_docker_pose_once(
    topic: str = "/amcl_pose",
    docker_container: Optional[str] = None,
) -> Optional[MapPose]:
    """单次从导航容器读取位姿（告警时用，不后台轮询）。"""
    cid = find_nav_container(docker_container)
    if not cid:
        return None
    cmd = [
        "docker", "exec", cid,
        "bash", "-lc",
        f"timeout 4 ros2 topic echo {topic} 2>/dev/null | head -40",
    ]
    try:
        out = subprocess.check_output(
            cmd, text=True, timeout=8, stderr=subprocess.DEVNULL,
        )
        return parse_amcl_echo(out)
    except Exception:
        return None


class AmclPoseReader:
    """
    订阅 /amcl_pose。
    backend=auto: 先 rclpy，失败则 docker exec 轮询。
    """

    def __init__(
        self,
        topic: str = "/amcl_pose",
        stale_sec: float = 3.0,
        backend: str = "auto",
        docker_container: Optional[str] = None,
        poll_sec: float = 0.5,
    ) -> None:
        self._topic = topic
        self._stale_sec = stale_sec
        self._backend = backend
        self._docker_container = docker_container
        self._poll_sec = poll_sec
        self._pose: Optional[MapPose] = None
        self._lock = threading.Lock()
        self._ready = False
        self._error: Optional[str] = None
        self._backend_name: Optional[str] = None
        self._stop = threading.Event()
        self._thread: Optional[threading.Thread] = None

    @property
    def error(self) -> Optional[str]:
        return self._error

    @property
    def ready(self) -> bool:
        return self._ready

    @property
    def backend_name(self) -> Optional[str]:
        return self._backend_name

    def start(self) -> None:
        if self._thread is not None:
            return
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=2.0)
            self._thread = None

    def get_pose(self) -> Optional[MapPose]:
        with self._lock:
            if self._pose is None:
                return None
            if time.time() - self._pose.stamp > self._stale_sec:
                return None
            return MapPose(
                x=self._pose.x,
                y=self._pose.y,
                yaw=self._pose.yaw,
                stamp=self._pose.stamp,
            )

    def _set_pose(self, pose: MapPose) -> None:
        with self._lock:
            self._pose = pose
            self._ready = True

    def _run(self) -> None:
        if self._backend in ("auto", "rclpy"):
            if self._try_rclpy():
                return
            if self._backend == "rclpy":
                return
        self._run_docker_poll()

    def _try_rclpy(self) -> bool:
        try:
            import rclpy
            from geometry_msgs.msg import PoseWithCovarianceStamped
            from rclpy.node import Node
        except Exception as exc:
            self._error = f"rclpy 不可用: {exc}"
            return False

        outer = self

        class _Node(Node):
            def __init__(self) -> None:
                super().__init__("patrol_pose_reader")
                self.create_subscription(
                    PoseWithCovarianceStamped, outer._topic, self._cb, 10
                )

            def _cb(self, msg: PoseWithCovarianceStamped) -> None:
                p = msg.pose.pose.position
                q = msg.pose.pose.orientation
                outer._set_pose(
                    MapPose(
                        x=float(p.x),
                        y=float(p.y),
                        yaw=_yaw_from_quaternion(q.x, q.y, q.z, q.w),
                        stamp=time.time(),
                    )
                )

        try:
            rclpy.init(args=None)
            node = _Node()
            self._backend_name = "rclpy"
            self._error = None
            while not self._stop.is_set() and rclpy.ok():
                rclpy.spin_once(node, timeout_sec=0.1)
            node.destroy_node()
            if rclpy.ok():
                rclpy.shutdown()
            return True
        except Exception as exc:
            self._error = str(exc)
            return False

    def _run_docker_poll(self) -> None:
        cid: Optional[str] = None
        while not self._stop.is_set():
            if cid is None:
                cid = find_nav_container(self._docker_container)
                if not cid:
                    self._error = "未找到运行中的 Docker 导航容器（docker ps）"
                    time.sleep(self._poll_sec)
                    continue
                self._backend_name = f"docker:{cid[:12]}"
                self._error = None

            cmd = [
                "docker", "exec", cid,
                "bash", "-lc",
                f"timeout 6 ros2 topic echo {self._topic} 2>/dev/null | head -40",
            ]
            try:
                out = subprocess.check_output(
                    cmd, text=True, timeout=12, stderr=subprocess.DEVNULL,
                )
                pose = parse_amcl_echo(out)
                if pose is not None:
                    self._set_pose(pose)
                elif not self._ready:
                    self._error = (
                        f"容器 {cid[:12]} 无 {self._topic} 数据"
                        "（需 n1 + RViz 2D Pose Estimate）"
                    )
            except subprocess.TimeoutExpired:
                if not self._ready:
                    self._error = f"等待 {self._topic} 超时（容器内是否已 n1？）"
            except Exception as exc:
                self._error = f"docker exec 失败: {exc}"
                cid = None
            time.sleep(self._poll_sec)
