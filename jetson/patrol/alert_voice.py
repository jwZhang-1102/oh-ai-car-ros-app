#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""告警语音播报：USB 音箱（espeak-ng/espeak + aplay 或 mpg123）。"""
from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path
from typing import Dict, Optional

# 类别 → 播报文案
DEFAULT_MESSAGES: Dict[str, str] = {
    "bottle": "检测到瓶子",
    "person": "检测到人员",
    "backpack": "检测到背包",
    "chair": "检测到椅子",
}

_last_spoke_at: float = 0.0
_min_gap_sec: float = 2.0


def default_alsa_device() -> str:
    return (
        os.environ.get("ALERT_VOICE_ALSA_DEVICE")
        or os.environ.get("MUSIC_ALSA_DEVICE")
        or "plughw:0,0"
    )


def message_for_class(cls_name: str, custom: Optional[str] = None) -> str:
    if custom:
        return custom
    return DEFAULT_MESSAGES.get(cls_name, "检测到异物")


def _run_audio(cmd: list, blocking: bool) -> bool:
    try:
        if blocking:
            subprocess.run(
                cmd, timeout=12, check=True,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
        else:
            subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        return True
    except Exception:
        return False


def _speak_espeak(text: str, device: str, blocking: bool) -> bool:
    espeak = shutil.which("espeak-ng") or shutil.which("espeak")
    aplay = shutil.which("aplay")
    if not espeak:
        return False
    # 中文优先 zh / cmn；无中文语音时 espeak 可能仍可读拼音或英文
    voices = ["zh", "cmn", "zh-yue", "default"]
    for voice in voices:
        if aplay and device:
            cmd = [
                "bash", "-lc",
                f"{espeak} -v {voice} -s 150 {_shell_quote(text)} --stdout | "
                f"aplay -q -D {_shell_quote(device)}",
            ]
        else:
            cmd = [espeak, "-v", voice, "-s", "150", text]
        if _run_audio(cmd, blocking):
            return True
    return False


def _play_file(path: Path, device: str, blocking: bool) -> bool:
    if not path.is_file():
        return False
    low = path.suffix.lower()
    if low in (".mp3", ".mpeg"):
        if not shutil.which("mpg123"):
            return False
        cmd = ["mpg123", "-q", "-a", device, str(path)]
        return _run_audio(cmd, blocking)
    if low in (".wav", ".wave"):
        aplay = shutil.which("aplay")
        if not aplay:
            return False
        cmd = [aplay, "-q", "-D", device, str(path)]
        return _run_audio(cmd, blocking)
    return False


def _shell_quote(s: str) -> str:
    return "'" + s.replace("'", "'\"'\"'") + "'"


def speak_alert(
    cls_name: str,
    text: Optional[str] = None,
    device: Optional[str] = None,
    wav_dir: Optional[Path] = None,
    blocking: bool = False,
    min_gap_sec: float = 2.0,
) -> bool:
    """
    播报告警语音。优先预录音频 alert_<class>.mp3/wav，否则 TTS。
    非阻塞默认；min_gap_sec 内重复调用会跳过。
    """
    global _last_spoke_at, _min_gap_sec
    import time

    now = time.time()
    _min_gap_sec = max(0.0, min_gap_sec)
    if now - _last_spoke_at < _min_gap_sec:
        return False

    msg = message_for_class(cls_name, text)
    dev = device or default_alsa_device()
    base = wav_dir or Path.home()

    # 预录文件：~/alert_bottle.mp3 或脚本目录 alert_bottle.wav
    for directory in (base, Path(__file__).resolve().parent):
        for ext in (".mp3", ".wav"):
            candidate = directory / f"alert_{cls_name}{ext}"
            if _play_file(candidate, dev, blocking):
                _last_spoke_at = now
                return True

    if _speak_espeak(msg, dev, blocking):
        _last_spoke_at = now
        return True

    return False
