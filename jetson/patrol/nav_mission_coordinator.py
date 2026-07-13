#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自主导航任务协调器：YOLO 告警 → 暂停 Nav2 → 记录 → 人工绕过 → 恢复至终点。

与 Docker Nav2 并行，通过 docker exec 控制容器内 ROS2（不占宿主机串口）。

用法:
  cd ~/Rosmaster-App/rosmaster
  # 通常由 patrol_server.py 自动加载，无需单独启动
  python3 nav_mission_coordinator.py status
  python3 nav_mission_coordinator.py resume
  python3 nav_mission_coordinator.py teleop 0.2 0 0   # vx vy wz
"""
from __future__ import annotations

import json
import math
import subprocess
import threading
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from pose_reader import find_nav_container
from rosmaster_buzzer import BuzzerController

WORK_DIR = Path(__file__).resolve().parent
WAYPOINTS_FILE = WORK_DIR / "mission_waypoints.json"
STATE_FILE = WORK_DIR / "mission_state.json"

GOAL_TOPIC = "/goal_pose"
CMD_VEL_TOPIC = "/cmd_vel"


class MissionState(str, Enum):
    IDLE = "idle"
    NAVIGATING = "navigating"
    ALERT_STOPPED = "alert_stopped"
    MANUAL_OVERRIDE = "manual_override"
    RESUMING = "resuming"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass
class GoalPose:
    x: float
    y: float
    yaw: float

    def to_dict(self) -> Dict[str, float]:
        return {"x": self.x, "y": self.y, "yaw": self.yaw}

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> Optional["GoalPose"]:
        if not data:
            return None
        try:
            return cls(
                x=float(data["x"]),
                y=float(data["y"]),
                yaw=float(data.get("yaw", 0.0)),
            )
        except (KeyError, TypeError, ValueError):
            return None


@dataclass
class MissionStatus:
    state: str = MissionState.IDLE.value
    frame_id: str = "map"
    end_goal: Optional[Dict[str, float]] = None
    last_alert_class: Optional[str] = None
    last_alert_event_id: Optional[str] = None
    last_alert_time: Optional[str] = None
    nav_paused: bool = False
    message: str = ""
    updated_at: str = field(default_factory=lambda: _now_str())
    pause_count: int = 0

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        return d


def _now_str() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def _yaw_to_quaternion(yaw: float) -> Tuple[float, float, float, float]:
    half = yaw * 0.5
    return (0.0, 0.0, math.sin(half), math.cos(half))


def _shell_quote(s: str) -> str:
    return "'" + s.replace("'", "'\"'\"'") + "'"


class NavDockerControl:
    """通过 docker exec 在导航容器内执行 ROS2 命令。"""

    def __init__(self, docker_container: Optional[str] = None) -> None:
        self._explicit_cid = docker_container.strip() if docker_container else None
        self._last_error: Optional[str] = None

    @property
    def last_error(self) -> Optional[str]:
        return self._last_error

    def container_id(self) -> Optional[str]:
        return find_nav_container(self._explicit_cid)

    def _exec(
        self,
        inner: str,
        timeout: float = 12.0,
        ignore_error: bool = False,
    ) -> Tuple[bool, str]:
        cid = self.container_id()
        if not cid:
            self._last_error = "未找到运行中的 Docker 导航容器"
            return False, self._last_error

        cmd = ["docker", "exec", cid, "bash", "-lc", inner]
        try:
            out = subprocess.check_output(
                cmd, text=True, timeout=timeout, stderr=subprocess.STDOUT,
            )
            self._last_error = None
            return True, out.strip()
        except subprocess.CalledProcessError as exc:
            msg = (exc.output or str(exc)).strip()
            self._last_error = msg
            return ignore_error, msg
        except Exception as exc:
            self._last_error = str(exc)
            return False, self._last_error

    def topic_exists(self, topic: str) -> bool:
        ok, out = self._exec(
            f"ros2 topic list 2>/dev/null | grep -Fx {_shell_quote(topic)}",
            timeout=8,
            ignore_error=True,
        )
        return ok and topic in out

    def publish_cmd_vel(
        self, vx: float = 0.0, vy: float = 0.0, wz: float = 0.0, repeat: int = 1,
    ) -> bool:
        msg = (
            f'{{linear: {{x: {vx}, y: {vy}, z: 0.0}}, '
            f'angular: {{x: 0.0, y: 0.0, z: {wz}}}}}'
        )
        inner = (
            f"for i in $(seq 1 {repeat}); do "
            f"ros2 topic pub --once {CMD_VEL_TOPIC} geometry_msgs/msg/Twist "
            f"{_shell_quote(msg)} 2>/dev/null; "
            f"sleep 0.08; done"
        )
        ok, _ = self._exec(inner, timeout=6 + repeat * 0.5, ignore_error=True)
        return ok

    def pause_bt_navigator(self) -> bool:
        services = [
            "/bt_navigator/pause",
            "/navigator/pause",
        ]
        for svc in services:
            ok, _ = self._exec(
                f"ros2 service call {svc} std_srvs/srv/Trigger " + "{} 2>/dev/null",
                timeout=8,
                ignore_error=True,
            )
            if ok:
                return True
        return False

    def resume_bt_navigator(self) -> bool:
        services = [
            "/bt_navigator/resume",
            "/navigator/resume",
        ]
        for svc in services:
            ok, _ = self._exec(
                f"ros2 service call {svc} std_srvs/srv/Trigger " + "{} 2>/dev/null",
                timeout=8,
                ignore_error=True,
            )
            if ok:
                return True
        return False

    def cancel_nav_goals(self) -> bool:
        cancel_cmds = [
            "ros2 service call /navigate_to_pose/_action/cancel_goal "
            "action_msgs/srv/CancelGoal {} 2>/dev/null",
            "ros2 service call /bt_navigator/navigate_to_pose/_action/cancel_goal "
            "action_msgs/srv/CancelGoal {} 2>/dev/null",
        ]
        any_ok = False
        for inner in cancel_cmds:
            ok, _ = self._exec(inner, timeout=8, ignore_error=True)
            any_ok = any_ok or ok
        return any_ok

    def publish_goal_pose(
        self, goal: GoalPose, frame_id: str = "map", topic: str = GOAL_TOPIC,
    ) -> bool:
        qx, qy, qz, qw = _yaw_to_quaternion(goal.yaw)
        msg = (
            "{header: {frame_id: '" + frame_id + "'}, "
            "pose: {position: {x: " + str(goal.x) + ", y: " + str(goal.y) + ", z: 0.0}, "
            "orientation: {x: " + str(qx) + ", y: " + str(qy) + ", z: " + str(qz) + ", w: " + str(qw) + "}}}"
        )
        actual_topic = topic
        if not self.topic_exists(topic):
            for alt in ("/goal_pose", "/move_base_simple/goal", "/goal"):
                if self.topic_exists(alt):
                    actual_topic = alt
                    break
        inner = (
            f"ros2 topic pub --once {actual_topic} geometry_msgs/msg/PoseStamped "
            f"{_shell_quote(msg)} 2>/dev/null"
        )
        ok, out = self._exec(inner, timeout=10, ignore_error=True)
        if not ok:
            self._last_error = f"发布 {actual_topic} 失败: {out}"
        return ok


class MissionCoordinator:
    """任务状态机：告警停车、人工接管、恢复导航。"""

    def __init__(
        self,
        waypoints_file: Path = WAYPOINTS_FILE,
        state_file: Path = STATE_FILE,
        docker_container: Optional[str] = None,
        buzzer_ms: int = 500,
        tcp_host: str = "127.0.0.1",
        tcp_port: int = 6000,
    ) -> None:
        self._waypoints_file = waypoints_file
        self._state_file = state_file
        self._nav = NavDockerControl(docker_container)
        self._buzzer_ms = buzzer_ms
        self._buzzer = BuzzerController(
            tcp_host=tcp_host, tcp_port=tcp_port, prefer_lib=False,
        )
        self._lock = threading.Lock()
        self._status = MissionStatus()
        self._frame_id = "map"
        self._end_goal: Optional[GoalPose] = None
        self._teleop_vx = 0.0
        self._teleop_vy = 0.0
        self._teleop_wz = 0.0
        self._teleop_until = 0.0
        self._teleop_thread: Optional[threading.Thread] = None
        self._teleop_stop = threading.Event()
        self._load_waypoints()
        self._load_state()
        self._ensure_teleop_thread()

    def _ensure_teleop_thread(self) -> None:
        if self._teleop_thread is not None and self._teleop_thread.is_alive():
            return
        self._teleop_stop.clear()
        self._teleop_thread = threading.Thread(
            target=self._teleop_loop, daemon=True, name="mission_teleop",
        )
        self._teleop_thread.start()

    def _teleop_loop(self) -> None:
        while not self._teleop_stop.is_set():
            vx = vy = wz = 0.0
            publish = False
            with self._lock:
                state = self._status.state
                if state in (
                    MissionState.ALERT_STOPPED.value,
                    MissionState.MANUAL_OVERRIDE.value,
                ):
                    if time.time() < self._teleop_until:
                        vx, vy, wz = self._teleop_vx, self._teleop_vy, self._teleop_wz
                        publish = abs(vx) > 1e-4 or abs(vy) > 1e-4 or abs(wz) > 1e-4
            if publish:
                self._nav.publish_cmd_vel(vx, vy, wz, repeat=1)
            time.sleep(0.1)

    def _persist_state(self) -> None:
        self._status.updated_at = _now_str()
        try:
            self._state_file.write_text(
                json.dumps(self._status.to_dict(), ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
        except Exception:
            pass

    def _set_state(
        self,
        state: MissionState,
        message: str = "",
        nav_paused: Optional[bool] = None,
    ) -> None:
        self._status.state = state.value
        self._status.message = message
        if nav_paused is not None:
            self._status.nav_paused = nav_paused
        if self._end_goal is not None:
            self._status.end_goal = self._end_goal.to_dict()
        self._status.frame_id = self._frame_id
        self._persist_state()

    def _load_waypoints(self) -> None:
        if not self._waypoints_file.is_file():
            return
        try:
            data = json.loads(self._waypoints_file.read_text(encoding="utf-8"))
            self._frame_id = str(data.get("frame_id", "map"))
            self._end_goal = GoalPose.from_dict(data.get("end", {}))
            if self._end_goal is not None:
                self._status.end_goal = self._end_goal.to_dict()
        except Exception as exc:
            print(f"[mission] WARN: 读取 waypoints 失败: {exc}", flush=True)

    def _load_state(self) -> None:
        if not self._state_file.is_file():
            return
        try:
            data = json.loads(self._state_file.read_text(encoding="utf-8"))
            self._status = MissionStatus(
                state=data.get("state", MissionState.IDLE.value),
                frame_id=data.get("frame_id", "map"),
                end_goal=data.get("end_goal"),
                last_alert_class=data.get("last_alert_class"),
                last_alert_event_id=data.get("last_alert_event_id"),
                last_alert_time=data.get("last_alert_time"),
                nav_paused=bool(data.get("nav_paused", False)),
                message=data.get("message", ""),
                updated_at=data.get("updated_at", _now_str()),
                pause_count=int(data.get("pause_count", 0)),
            )
            if self._status.end_goal:
                self._end_goal = GoalPose.from_dict(self._status.end_goal)
        except Exception:
            pass

    def reload_waypoints(self) -> Dict[str, Any]:
        with self._lock:
            self._load_waypoints()
            if self._end_goal is not None:
                self._status.end_goal = self._end_goal.to_dict()
                self._persist_state()
            return {
                "ok": True,
                "end_goal": self._end_goal.to_dict() if self._end_goal else None,
            }

    def set_end_goal(self, x: float, y: float, yaw: float = 0.0) -> Dict[str, Any]:
        with self._lock:
            self._end_goal = GoalPose(x=x, y=y, yaw=yaw)
            self._status.end_goal = self._end_goal.to_dict()
            data = {
                "frame_id": self._frame_id,
                "end": self._end_goal.to_dict(),
                "note": "由 POST /mission/set_end 更新",
            }
            self._waypoints_file.write_text(
                json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            if self._status.state == MissionState.IDLE.value:
                self._set_state(MissionState.NAVIGATING, "已设置终点，等待 RViz 导航或恢复指令")
            self._persist_state()
            return {"ok": True, "end_goal": self._end_goal.to_dict()}

    def start_mission(self) -> Dict[str, Any]:
        with self._lock:
            self._load_waypoints()
            if self._end_goal is None:
                return {
                    "ok": False,
                    "error": "mission_waypoints.json 未配置有效 end 坐标",
                }
            self._set_state(
                MissionState.NAVIGATING,
                "任务已启动；请在 RViz 设 2D Pose Estimate 并 2D Goal Pose（或与 JSON 终点一致）",
                nav_paused=False,
            )
            return {"ok": True, "state": self._status.state, "end_goal": self._end_goal.to_dict()}

    def get_status(self) -> Dict[str, Any]:
        with self._lock:
            return self._status.to_dict()

    def _pause_navigation(self) -> str:
        notes: List[str] = []
        if self._nav.pause_bt_navigator():
            notes.append("bt_navigator pause")
        if self._nav.cancel_nav_goals():
            notes.append("cancel goals")
        if self._nav.publish_cmd_vel(0, 0, 0, repeat=5):
            notes.append("cmd_vel zero")
        if not notes:
            err = self._nav.last_error or "暂停导航失败"
            return err
        return ", ".join(notes)

    def on_alert(
        self,
        cls_name: str,
        event_id: Optional[str] = None,
        confidence: Optional[float] = None,
    ) -> Dict[str, Any]:
        with self._lock:
            if self._status.state in (
                MissionState.ALERT_STOPPED.value,
                MissionState.MANUAL_OVERRIDE.value,
            ):
                return {
                    "ok": True,
                    "state": self._status.state,
                    "nav_paused": True,
                    "skipped": True,
                    "message": "已在停车/接管状态",
                }

            pause_note = self._pause_navigation()
            beep_ok = self._buzzer.beep(self._buzzer_ms)

            self._status.last_alert_class = cls_name
            self._status.last_alert_event_id = event_id
            self._status.last_alert_time = _now_str()
            self._status.pause_count += 1
            conf_txt = f" conf={confidence:.2f}" if confidence is not None else ""
            msg = (
                f"YOLO 告警停车 class={cls_name}{conf_txt}; {pause_note}"
                f"; beep={'ok' if beep_ok else 'fail'}"
            )
            self._set_state(MissionState.ALERT_STOPPED, msg, nav_paused=True)

            print(f"[mission] ALERT_STOPPED {msg}", flush=True)
            return {
                "ok": True,
                "state": self._status.state,
                "nav_paused": True,
                "message": msg,
                "beep": beep_ok,
            }

    def enter_manual(self) -> Dict[str, Any]:
        with self._lock:
            if self._status.state not in (
                MissionState.ALERT_STOPPED.value,
                MissionState.MANUAL_OVERRIDE.value,
            ):
                return {
                    "ok": False,
                    "error": f"当前状态 {self._status.state} 不能进入人工接管",
                }
            self._set_state(
                MissionState.MANUAL_OVERRIDE,
                "人工接管：POST /mission/teleop 发送速度，绕障后 POST /mission/resume",
                nav_paused=True,
            )
            return {"ok": True, "state": self._status.state}

    def teleop(
        self,
        vx: float,
        vy: float = 0.0,
        wz: float = 0.0,
        duration_sec: float = 0.5,
    ) -> Dict[str, Any]:
        with self._lock:
            if self._status.state not in (
                MissionState.ALERT_STOPPED.value,
                MissionState.MANUAL_OVERRIDE.value,
            ):
                return {
                    "ok": False,
                    "error": f"当前状态 {self._status.state} 不允许 teleop",
                }
            if self._status.state == MissionState.ALERT_STOPPED.value:
                self._status.state = MissionState.MANUAL_OVERRIDE.value
                self._status.message = "告警后 teleop 已进入人工接管"
            self._teleop_vx = float(vx)
            self._teleop_vy = float(vy)
            self._teleop_wz = float(wz)
            self._teleop_until = time.time() + max(0.1, duration_sec)
            self._persist_state()
            return {
                "ok": True,
                "state": self._status.state,
                "vx": self._teleop_vx,
                "vy": self._teleop_vy,
                "wz": self._teleop_wz,
            }

    def stop_teleop(self) -> Dict[str, Any]:
        with self._lock:
            self._teleop_vx = self._teleop_vy = self._teleop_wz = 0.0
            self._teleop_until = 0.0
        self._nav.publish_cmd_vel(0, 0, 0, repeat=3)
        return {"ok": True}

    def resume(self) -> Dict[str, Any]:
        with self._lock:
            self._load_waypoints()
            if self._end_goal is None:
                return {
                    "ok": False,
                    "error": "无终点坐标：编辑 mission_waypoints.json 或 POST /mission/set_end",
                }

            self._teleop_vx = self._teleop_vy = self._teleop_wz = 0.0
            self._teleop_until = 0.0
            self._nav.publish_cmd_vel(0, 0, 0, repeat=3)
            self._set_state(MissionState.RESUMING, "正在恢复导航至终点", nav_paused=False)

        goal_ok = self._nav.publish_goal_pose(
            self._end_goal, frame_id=self._frame_id,
        )
        resume_ok = self._nav.resume_bt_navigator()

        with self._lock:
            notes: List[str] = []
            if goal_ok:
                notes.append(f"goal {self._end_goal.to_dict()}")
            if resume_ok:
                notes.append("bt_navigator resume")
            if not goal_ok and not resume_ok:
                err = self._nav.last_error or "恢复失败"
                self._set_state(MissionState.FAILED, err, nav_paused=True)
                return {"ok": False, "error": err, "state": self._status.state}

            msg = "已恢复导航: " + ", ".join(notes)
            self._set_state(MissionState.NAVIGATING, msg, nav_paused=False)
            print(f"[mission] RESUME {msg}", flush=True)
            return {
                "ok": True,
                "state": self._status.state,
                "message": msg,
                "end_goal": self._end_goal.to_dict(),
            }


# patrol_server 使用的单例
_coordinator: Optional[MissionCoordinator] = None
_coordinator_lock = threading.Lock()


def get_coordinator() -> MissionCoordinator:
    global _coordinator
    with _coordinator_lock:
        if _coordinator is None:
            _coordinator = MissionCoordinator()
        return _coordinator


def _cli_main() -> None:
    import argparse

    p = argparse.ArgumentParser(description="导航任务协调器 CLI")
    p.add_argument(
        "action",
        choices=["status", "start", "resume", "manual", "reload", "teleop"],
    )
    p.add_argument("vx", nargs="?", type=float, default=0.0)
    p.add_argument("vy", nargs="?", type=float, default=0.0)
    p.add_argument("wz", nargs="?", type=float, default=0.0)
    args = p.parse_args()

    coord = get_coordinator()
    if args.action == "status":
        print(json.dumps(coord.get_status(), ensure_ascii=False, indent=2))
    elif args.action == "start":
        print(json.dumps(coord.start_mission(), ensure_ascii=False, indent=2))
    elif args.action == "resume":
        print(json.dumps(coord.resume(), ensure_ascii=False, indent=2))
    elif args.action == "manual":
        print(json.dumps(coord.enter_manual(), ensure_ascii=False, indent=2))
    elif args.action == "reload":
        print(json.dumps(coord.reload_waypoints(), ensure_ascii=False, indent=2))
    elif args.action == "teleop":
        print(json.dumps(
            coord.teleop(args.vx, args.vy, args.wz, duration_sec=0.6),
            ensure_ascii=False, indent=2,
        ))


if __name__ == "__main__":
    _cli_main()
