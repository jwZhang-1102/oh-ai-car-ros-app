#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
音乐伴舞：goodnight.MP3 + Rosmaster 底盘/车灯编舞。

用法（Jetson 宿主机，串口不能被 ros/run / Docker n1 占用）:
  cd ~/Rosmaster-App/rosmaster/jetson/patrol   # 或 music.py 与 goodnight.MP3 同目录
  python3 music.py

依赖: Rosmaster_Lib, librosa, playsound（可选）; 播放优先 mpg123/ffplay。
"""
import os
import subprocess
import threading
import time

import librosa
from Rosmaster_Lib import Rosmaster

try:
    from playsound import playsound
except ImportError:
    playsound = None

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_MUSIC = os.path.join(SCRIPT_DIR, "goodnight.MP3")
g_debug = True


def _alsa_device() -> str:
    """默认 USB 音箱 card 0；可 export MUSIC_ALSA_DEVICE=hw:3,3 改 HDMI 等。"""
    return os.environ.get("MUSIC_ALSA_DEVICE", "hw:0,0")


def play_music_background(sound_path: str) -> bool:
    """Jetson 上 playsound 常无声，优先 mpg123 并指定 ALSA 设备。"""
    if not os.path.isfile(sound_path):
        print(f"[music] 找不到音乐文件: {sound_path}")
        return False

    alsa = _alsa_device()
    players = [
        ["mpg123", "-q", "-a", alsa, sound_path],
        ["mpg123", "-q", sound_path],
        ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", sound_path],
        ["cvlc", "--play-and-exit", "--quiet", sound_path],
    ]
    for cmd in players:
        try:
            subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            extra = f" -a {alsa}" if cmd[0] == "mpg123" and "-a" in cmd else ""
            print(f"[music] 正在播放: {sound_path} （{cmd[0]}{extra}）")
            return True
        except FileNotFoundError:
            continue
        except Exception as e:
            print(f"[music] {cmd[0]} 失败: {e}")

    if playsound is not None:
        def _play():
            try:
                playsound(sound_path, block=True)
            except Exception as e:
                print(f"[music] playsound 失败: {e}")

        threading.Thread(target=_play, daemon=True).start()
        print(f"[music] 正在播放: {sound_path} （playsound）")
        return True

    print("[music] 无可用播放器，请安装: sudo apt install -y mpg123")
    print("[music] 或: sudo apt install -y ffmpeg  （提供 ffplay）")
    return False


def headlights_async(bot, left_on, right_on, duration_ms):
    """异步控灯：兼容新版 Rosmaster_Lib（勿用私有属性 __HEAD）。"""
    try:
        bot.set_headlights_control(left_on, right_on, duration_ms)
    except Exception as e:
        print(f"[music] headlights error: {e}")


def start_headlights(bot, left_on, right_on, duration_ms):
    threading.Thread(
        target=headlights_async,
        args=(bot, left_on, right_on, duration_ms),
        daemon=True,
    ).start()


def detect_beats(audio_path):
    y, sr = librosa.load(audio_path)
    onset_env = librosa.onset.onset_strength(y=y, sr=sr)
    _, beat_frames = librosa.beat.beat_track(onset_envelope=onset_env, sr=sr)
    return librosa.frames_to_time(beat_frames, sr=sr)


def perform_actions(sound_path=None):
    sound_path = sound_path or DEFAULT_MUSIC
    if not os.path.isfile(sound_path):
        sound_path = os.path.join(os.getcwd(), "goodnight.MP3")

    bot = Rosmaster(debug=g_debug)
    bot.create_receive_threading()

    play_music_background(sound_path)

    beat_times = []
    if os.path.isfile(sound_path):
        try:
            beat_times = detect_beats(sound_path)
        except Exception as e:
            print(f"[music] 节拍分析跳过: {e}")

    try:
        start_headlights(bot, 1, 0, 400)
        bot.set_car_run(1, 20)
        time.sleep(0.4)

        start_headlights(bot, 0, 1, 733)
        bot.set_car_run(4, 20)
        time.sleep(0.733)

        start_headlights(bot, 1, 1, 1000)
        bot.set_car_run(1, 50)
        time.sleep(1.0)

        start_headlights(bot, 0, 0, 100)
        bot.set_car_run(0, 0)
        time.sleep(0.6)

        start_headlights(bot, 1, 1, 4000)
        bot.set_car_run(5, 20)
        time.sleep(3.867)

        for _ in range(2):
            start_headlights(bot, 1, 1, 200)
            time.sleep(0.2)
            start_headlights(bot, 0, 0, 200)
            time.sleep(0.2)

        start_headlights(bot, 1, 1, 3083)
        bot.set_car_run(6, 20)
        time.sleep(3.083)

        start_headlights(bot, 0, 0, 200)
        bot.set_car_run(1, 40)
        time.sleep(3.99)
        start_headlights(bot, 1, 1, 200)
        time.sleep(0.2)
        start_headlights(bot, 0, 0, 200)
        time.sleep(0.2)

        start_headlights(bot, 0, 0, 3784)
        bot.set_car_run(2, 40)
        time.sleep(3.784)

        bot.set_car_run(4, 30)
        for i in range(6):
            start_headlights(bot, 0, 1 if i % 2 else 0, 500)
            time.sleep(0.5)
        start_headlights(bot, 0, 0, 500)

        bot.set_car_run(3, 30)
        for i in range(6):
            start_headlights(bot, 1, 1 if i % 2 else 0, 500)
            time.sleep(0.5)

        bot.set_car_run(6, 100)
        time.sleep(3.78)

        for beat_time in beat_times:
            print(f"Detected beat at: {beat_time:.3f} seconds")
            start_headlights(bot, 1, 1, 200)
            time.sleep(0.1)
            start_headlights(bot, 0, 0, 200)
            time.sleep(0.1)

    finally:
        bot.set_car_run(0, 0)
        start_headlights(bot, 0, 0, 0)


if __name__ == "__main__":
    perform_actions()
