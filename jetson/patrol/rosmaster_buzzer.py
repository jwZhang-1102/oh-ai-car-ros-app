#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Rosmaster 蜂鸣器控制：优先 Rosmaster_Lib，其次 TCP cmd=13。"""
from __future__ import annotations

import socket
from typing import Optional


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


class BuzzerController:
    def __init__(
        self,
        tcp_host: str = "127.0.0.1",
        tcp_port: int = 6000,
        prefer_lib: bool = True,
    ) -> None:
        """
        prefer_lib=False：不打开 Rosmaster 串口（Docker n1/n3 导航并行时必须关闭）。
        """
        self._tcp_host = tcp_host
        self._tcp_port = tcp_port
        self._bot = None
        self._lib_ok = False
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
        return self._lib_ok

    def beep(self, on_time: int = 500) -> bool:
        """触发蜂鸣；成功返回 True。"""
        if self._lib_ok and self._bot is not None:
            try:
                self._bot.set_beep(on_time)
                return True
            except Exception:
                pass

        try:
            payload = encode_buzzer_tcp(on_time)
            with socket.create_connection(
                (self._tcp_host, self._tcp_port), timeout=1.5
            ) as sock:
                sock.sendall(payload)
            return True
        except Exception:
            return False

    def off(self) -> bool:
        return self.beep(0)
