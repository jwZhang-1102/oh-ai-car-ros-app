#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
音乐伴舞：MP3 + Rosmaster 底盘动作（不控灯）。

用法（Jetson 宿主机，串口不能被 ros/run / Docker n1 占用）:
  python3 music.py
  python3 music.py ~/goodnight.MP3

依赖: Rosmaster_Lib, mpg123/ffplay。
"""
from __future__ import print_function

import os
import subprocess
import sys
import threading
import time

from Rosmaster_Lib import Rosmaster

try:
    from playsound import playsound
except ImportError:
    playsound = None

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
HOME_DIR = os.path.expanduser("~")
g_debug = True


def resolve_music_path(sound_path=None):
    """查找 MP3：用户指定 → 脚本目录 → 家目录 → 当前目录。"""
    if sound_path:
        p = os.path.expanduser(sound_path)
        if os.path.isfile(p):
            return os.path.abspath(p)
        print("[music] 指定路径不存在: {0}".format(p))

    for d in (SCRIPT_DIR, HOME_DIR, os.getcwd()):
        for name in ("goodnight.MP3", "goodnight.mp3", "GOODNIGHT.MP3"):
            p = os.path.join(d, name)
            if os.path.isfile(p):
                return os.path.abspath(p)
    return None


def _alsa_device():
    """默认 USB 音箱；可用 MUSIC_ALSA_DEVICE=plughw:0,0 覆盖。"""
    return os.environ.get("MUSIC_ALSA_DEVICE", "plughw:0,0")


def _unmute_usb_pcm():
    """重启后 PCM 常被置 0%，播前拉满。"""
    try:
        subprocess.call(
            ["amixer", "-c", "0", "set", "PCM", "100%", "unmute"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass


def play_music_background(sound_path):
    """后台启动播放；绝不阻塞等整首歌播完。"""
    if not sound_path or not os.path.isfile(sound_path):
        print("[music] 找不到音乐文件: {0}".format(sound_path))
        return False

    _unmute_usb_pcm()
    alsa = _alsa_device()
    players = [
        ["mpg123", "-q", "-a", alsa, sound_path],
        ["mpg123", "-q", "-a", "hw:0,0", sound_path],
        ["mpg123", "-q", sound_path],
        ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", sound_path],
        ["cvlc", "--play-and-exit", "--quiet", sound_path],
    ]
    for cmd in players:
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            time.sleep(0.12)
            if proc.poll() is None:
                print("[music] 正在播放: {0} （{1}）".format(sound_path, " ".join(cmd[:3])))
                return True
            print("[music] {0} 立刻退出，试下一个…".format(cmd[0]))
        except FileNotFoundError:
            continue
        except Exception as e:
            print("[music] {0} 失败: {1}".format(cmd[0], e))

    if playsound is not None:
        def _play():
            try:
                playsound(sound_path, block=True)
            except Exception as e:
                print("[music] playsound 失败: {0}".format(e))

        threading.Thread(target=_play, daemon=True).start()
        print("[music] 正在播放: {0} （playsound）".format(sound_path))
        return True

    print("[music] 无可用播放器，请: sudo apt install -y mpg123")
    return False


def perform_actions(sound_path=None):
    sound_path = resolve_music_path(sound_path)
    if not sound_path:
        print("[music] 请把 goodnight.MP3 放在 ~ 或与 music.py 同目录")
        print("[music] 或: python3 music.py ~/goodnight.MP3")
        return

    print("[music] 音乐文件: {0}".format(sound_path))
    # 先连底盘（会安静几秒），再「同时」放歌+跳舞，对拍才稳定
    print("[music] 连接底盘…")
    bot = Rosmaster(debug=g_debug)
    bot.create_receive_threading()
    bot.set_car_run(0, 0)
    time.sleep(0.15)

    if not play_music_background(sound_path):
        print("[music] 手动试: mpg123 -a {0} {1}".format(_alsa_device(), sound_path))
    print("[music] 开始跳舞（与音乐同步开场）")

    try:
        bot.set_car_run(1, 20)
        time.sleep(0.4)

        bot.set_car_run(4, 20)
        time.sleep(0.733)

        bot.set_car_run(1, 50)
        time.sleep(1.0)

        bot.set_car_run(0, 0)
        time.sleep(0.6)

        bot.set_car_run(5, 20)
        time.sleep(3.867)

        time.sleep(0.8)

        bot.set_car_run(6, 20)
        time.sleep(3.083)

        bot.set_car_run(1, 40)
        time.sleep(4.39)

        bot.set_car_run(2, 40)
        time.sleep(3.784)

        bot.set_car_run(4, 30)
        time.sleep(3.0)

        bot.set_car_run(3, 30)
        time.sleep(3.0)

        bot.set_car_run(6, 100)
        time.sleep(3.78)

    finally:
        bot.set_car_run(0, 0)
        print("[music] 结束")


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else None
    perform_actions(arg)
