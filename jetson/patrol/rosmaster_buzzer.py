#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Rosmaster 蜂鸣器控制。

优先级（可配置）:
  1. docker exec → ros2 topic /beep（n1 底盘节点已占串口，推荐）
  2. docker exec → 容器内 Rosmaster_Lib（串口已被 n1 占用时常失败）
  3. 宿主机 Rosmaster_Lib 串口
  4. TCP cmd=13 → 6000（需 ros/run）
"""
from __future__ import annotations

import subprocess
import time
from typing import Optional

from pose_reader import find_nav_container

# 告警时连响次数与间隔
ALERT_BEEP_REPEAT = 3
ALERT_BEEP_GAP_SEC = 0.18


def _checksum_hex(payload: str) -> str:
    total = 0
    for i in range(0, len(payload), 2):
        total = (total + int(payload[i:i + 2], 16)) % 256
    return f"{total:02X}"


def encode_buzzer_tcp(on_time: int) -> bytes:
    """
    构造 TCP 帧 cmd=13（设置蜂鸣器）。
    on_time: 0=关, 1=常响, >=10=响 on_time 毫秒（10 的倍数）。
    """
    if on_time < 0:
        on_time = 0
    if on_time <= 255:
        info = f"{on_time:02X}"
    else:
        info = f"{(on_time >> 8) & 0xFF:02X}{on_time & 0xFF:02X}"

    body = "01" + "13" + f"{len(info) + 2:02X}" + info
    frame = f"${body}{_checksum_hex(body)}#"
    return frame.encode("ascii")


def beep_via_docker_topic(
    on_time: int = 500,
    docker_container: Optional[str] = None,
) -> bool:
    """经 n1 底盘节点的 /beep 话题蜂鸣（串口已被占用时的正确方式）。"""
    cid = find_nav_container(docker_container)
    if not cid:
        return False
    ms = max(10, int(on_time))
    sleep_sec = max(0.05, ms / 1000.0)
    inner = (
        "if ros2 topic list 2>/dev/null | grep -qx '/beep'; then "
        f"ros2 topic pub --once /beep std_msgs/msg/UInt16 '{{data: {ms}}}' "
        "2>/dev/null; "
        "elif ros2 topic list 2>/dev/null | grep -Eiq '/buzzer'; then "
        "ros2 topic pub --once /buzzer std_msgs/msg/Bool '{data: true}' "
        "2>/dev/null; "
        f"sleep {sleep_sec}; "
        "ros2 topic pub --once /buzzer std_msgs/msg/Bool '{data: false}' "
        "2>/dev/null; "
        "else exit 1; fi"
    )
    try:
        subprocess.run(
            ["docker", "exec", cid, "bash", "-lc", inner],
            timeout=8,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True
    except Exception:
        return False


def beep_via_docker(
    on_time: int = 500,
    docker_container: Optional[str] = None,
) -> bool:
    """在导航 Docker 容器内直接 set_beep（n1 已占串口时通常不可用）。"""
    cid = find_nav_container(docker_container)
    if not cid:
        return False
    inner = (
        'python3 -c "from Rosmaster_Lib import Rosmaster; '
        "Rosmaster().set_beep({0})\"".format(int(on_time))
    )
    try:
        subprocess.run(
            ["docker", "exec", cid, "bash", "-lc", inner],
            timeout=6,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True
    except Exception:
        return False


class BuzzerController:
    def __init__(
        self,
        tcp_host: str = "127.0.0.1",
        tcp_port: int = 6000,
        prefer_lib: bool = True,
        prefer_docker: bool = False,
        docker_container: Optional[str] = None,
    ) -> None:
        """
        prefer_lib=False：不打开宿主机 Rosmaster 串口。
        prefer_docker=True：优先 docker exec 蜂鸣（与 n1 导航并行，不需 ros/run）。
        """
        self._tcp_host = tcp_host
        self._tcp_port = tcp_port
        self._prefer_docker = prefer_docker
        self._docker_container = docker_container
        self._bot = None
        self._lib_ok = False
        self._last_backend = ""
        if prefer_lib:
            self._try_init_lib()

    def _try_init_lib(self) -> None:
        try:
            from Rosmaster_Lib import Rosmaster  # type: ignore

            self._bot = Rosmaster()
            self._lib_ok = True
        except Exception:
            self._bot = None
            self._lib_ok = False

    @property
    def available(self) -> bool:
        return self._lib_ok or self._prefer_docker

    @property
    def last_backend(self) -> str:
        return self._last_backend

    def _beep_once(self, on_time: int) -> bool:
        if self._prefer_docker:
            if beep_via_docker_topic(on_time, self._docker_container):
                self._last_backend = "docker:ros2:/beep"
                return True
            if beep_via_docker(on_time, self._docker_container):
                self._last_backend = "docker:Rosmaster_Lib"
                return True

        if self._lib_ok and self._bot is not None:
            try:
                self._bot.set_beep(on_time)
                self._last_backend = "host:Rosmaster_Lib"
                return True
            except Exception:
                pass

        try:
            import socket

            payload = encode_buzzer_tcp(on_time)
            with socket.create_connection(
                (self._tcp_host, self._tcp_port), timeout=1.5
            ) as sock:
                sock.sendall(payload)
            self._last_backend = "tcp:{0}:{1}".format(self._tcp_host, self._tcp_port)
            return True
        except Exception:
            self._last_backend = ""
            return False

    def beep(
        self,
        on_time: int = 500,
        repeat: int = 1,
        gap_sec: float = ALERT_BEEP_GAP_SEC,
    ) -> bool:
        """触发蜂鸣；repeat>1 时连续多次，gap_sec 为间隔秒数。"""
        times = max(1, int(repeat))
        any_ok = False
        for i in range(times):
            if self._beep_once(on_time):
                any_ok = True
            if i < times - 1 and gap_sec > 0:
                time.sleep(gap_sec)
        return any_ok

    def beep_alert(self, on_time: int = 500) -> bool:
        """告警专用：连响 ALERT_BEEP_REPEAT 次。"""
        return self.beep(on_time, repeat=ALERT_BEEP_REPEAT, gap_sec=ALERT_BEEP_GAP_SEC)

    def off(self) -> bool:
        return self._beep_once(0)
