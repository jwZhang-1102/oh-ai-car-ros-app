#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
罗技 G29 → Jetson mission HTTP teleop（6700 /cmd_vel）

用于 Docker 导航 mission 模式告警后人工绕障，不走 TCP 6000，不与 n1 抢串口。

前置（Jetson 小车）:
  bash start_nav_docker.sh          # n1/n2/n3
  bash start_mission_nav.sh         # 巡检 + 告警停车
  # 路上检出异物 → alert_stopped 后再用本脚本

Windows 用法:
  cd D:\\oh-ai-car-ros-app\\tools
  python g29_mission_drive.py --backend winmm --calibrate
  python g29_mission_drive.py --backend winmm --ip 10.147.13.194 --mode pedal

绕障完成后（Jetson 或本机）:
  curl -X POST http://10.147.13.194:6700/mission/resume
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from typing import Dict, Optional

try:
    import pygame
except ImportError:
    pygame = None

# 复用 TCP 版 G29 读取与标定
from logitech_g29_drive import (
    calibrate,
    clamp,
    draw_status,
    make_reader,
    maybe_window,
    pedal01,
    pump_quit,
)

DEFAULT_PORT = 6700
BTN_ESTOP = 1


class MissionTeleopClient(object):
    """POST /mission/teleop → Docker /cmd_vel"""

    def __init__(self, host: str, port: int = DEFAULT_PORT, verbose: bool = False):
        self._base = "http://{0}:{1}".format(host, port)
        self._verbose = verbose
        self._last_log = 0.0

    def _request(
        self, method: str, path: str, body: Optional[Dict] = None, timeout: float = 2.5,
    ):
        url = self._base + path
        data = None
        headers = {}
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                raw = resp.read().decode("utf-8")
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as exc:
            err_body = exc.read().decode("utf-8", errors="replace")
            try:
                return json.loads(err_body)
            except json.JSONDecodeError:
                return {"ok": False, "error": err_body or str(exc)}
        except Exception as exc:
            return {"ok": False, "error": str(exc)}

    def health(self):
        return self._request("GET", "/health")

    def status(self):
        return self._request("GET", "/mission/status")

    def enter_manual(self):
        return self._request("POST", "/mission/manual")

    def teleop(self, vx: float, vy: float = 0.0, wz: float = 0.0, duration: float = 0.6):
        body = {"vx": vx, "vy": vy, "wz": wz, "duration": duration}
        if self._verbose:
            now = time.time()
            if now - self._last_log > 0.25:
                print("[G29-Mission] teleop vx={0:.3f} vy={1:.3f} wz={2:.3f}".format(
                    vx, vy, wz))
                self._last_log = now
        return self._request("POST", "/mission/teleop", body)

    def stop(self):
        return self._request("POST", "/mission/stop")

    def check_ready(self, auto_manual: bool = True):
        """确认 6700 可达且处于可 teleop 状态。"""
        h = self.health()
        if h.get("status") != "ok":
            print("[G29-Mission] WARN: /health 异常: {0}".format(h))
            return False

        st = self.status()
        state = st.get("state", "unknown")
        print("[G29-Mission] mission state={0}".format(state))
        if state in ("alert_stopped", "manual_override"):
            return True
        if state == "navigating":
            print(
                "[G29-Mission] 当前在自动导航，teleop 会被拒绝。\n"
                "  请先触发 YOLO 告警停车，或在小车执行 mission 演示流程。"
            )
            return False
        if state == "idle" and auto_manual:
            print("[G29-Mission] 尝试 POST /mission/manual …")
            r = self.enter_manual()
            if r.get("ok"):
                print("[G29-Mission] 已进入 manual_override（仅测试用）")
                return True
        print(
            "[G29-Mission] 不可 teleop（state={0}）。\n"
            "  正常流程: start_mission_nav.sh → 告警停车 → 再运行本脚本".format(state)
        )
        return False


def map_pedal_twist(
    clutch, brake, gas, steer,
    pedal_threshold, steer_threshold,
    max_linear, max_angular,
):
    """踏板模式 → ROS Twist（m/s, rad/s）。"""
    if brake >= pedal_threshold:
        return 0.0, 0.0, 0.0
    if clutch >= pedal_threshold:
        vx = -max_linear
        wz = steer * max_angular if abs(steer) >= steer_threshold else 0.0
        return vx, 0.0, wz
    if gas >= pedal_threshold:
        vx = max_linear
        wz = steer * max_angular if abs(steer) >= steer_threshold else 0.0
        return vx, 0.0, wz
    if abs(steer) >= steer_threshold:
        return 0.0, 0.0, steer * max_angular
    return 0.0, 0.0, 0.0


def map_drive_twist(steer, throttle, max_linear, max_angular):
    vx = clamp(throttle * max_linear, -max_linear, max_linear)
    wz = clamp(steer * max_angular, -max_angular, max_angular)
    return vx, 0.0, wz


def map_rotate_twist(steer, max_angular, min_angular=0.25, threshold=0.05):
    if abs(steer) < threshold:
        return 0.0, 0.0, 0.0
    wz = steer * max_angular
    if abs(wz) < min_angular:
        wz = min_angular if wz > 0 else -min_angular
    return 0.0, 0.0, clamp(wz, -max_angular, max_angular)


def map_arcade_twist(steer, throttle, max_linear, max_lateral):
    vx = clamp(throttle * max_linear, -max_linear, max_linear)
    vy = clamp(steer * max_lateral, -max_lateral, max_lateral)
    return vx, vy, 0.0


def drive_loop(reader, client, args, pedal_inverted):
    screen, font = maybe_window("G29 Mission Teleop")
    print("[G29-Mission] mode={0} url={1}:{2}".format(
        args.mode, args.ip, args.port))
    print("[G29-Mission] 踏板 L→R: 离合=后退 刹车=停 油门=前进")
    print("[G29-Mission] 绕障完成后: curl -X POST http://{0}:{1}/mission/resume".format(
        args.ip, args.port))

    steer_mul = -1.0 if args.invert_steer else 1.0
    interval = 1.0 / args.hz
    teleop_duration = max(0.15, interval * 4)
    last_err_log = 0.0
    teleop_rejected = False

    try:
        while pump_quit():
            steer, clutch, brake, gas, estop, raw, _ = reader.read(pedal_inverted)
            steer = steer * steer_mul
            throttle = gas - brake

            if estop:
                client.stop()
                vx = vy = wz = 0.0
            elif args.mode == "pedal":
                vx, vy, wz = map_pedal_twist(
                    clutch, brake, gas, steer,
                    args.pedal_threshold, args.steer_threshold,
                    args.max_linear, args.max_angular,
                )
            elif args.mode == "rotate":
                vx, vy, wz = map_rotate_twist(
                    steer, args.max_angular, args.min_angular, 0.05,
                )
            elif args.mode == "drive":
                if abs(throttle) < 0.02 and abs(steer) < 0.05:
                    vx = vy = wz = 0.0
                else:
                    vx, vy, wz = map_drive_twist(
                        steer, throttle, args.max_linear, args.max_angular,
                    )
            elif args.mode == "arcade":
                if abs(throttle) < 0.02 and abs(steer) < 0.05:
                    vx = vy = wz = 0.0
                else:
                    vx, vy, wz = map_arcade_twist(
                        steer, throttle, args.max_linear, args.max_lateral,
                    )
            else:
                vx = vy = wz = 0.0

            if estop or (abs(vx) < 1e-4 and abs(vy) < 1e-4 and abs(wz) < 1e-4):
                client.stop()
            else:
                resp = client.teleop(vx, vy, wz, duration=teleop_duration)
                if not resp.get("ok"):
                    now = time.time()
                    if now - last_err_log > 2.0:
                        print("[G29-Mission] teleop 被拒: {0}".format(
                            resp.get("error", resp)))
                        last_err_log = now
                    teleop_rejected = True

            draw_status(screen, font, [
                "G29 -> mission {0}:{1} mode={2}".format(args.ip, args.port, args.mode),
                "vx={0:+.2f} vy={1:+.2f} wz={2:+.2f}".format(vx, vy, wz),
                "gas={0:.2f} brake={1:.2f} steer={2:+.2f}".format(gas, brake, steer),
                "resume: curl -X POST .../mission/resume",
            ])
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\n[G29-Mission] 退出")
    finally:
        client.stop()
        if teleop_rejected:
            print("[G29-Mission] 提示: 需先告警停车(alert_stopped) 才能 teleop")
        if pygame is not None and pygame.get_init():
            pygame.quit()


def main():
    p = argparse.ArgumentParser(
        description="Logitech G29 -> Jetson mission HTTP teleop (6700)",
    )
    p.add_argument("--ip", default="10.147.13.194", help="Jetson IP")
    p.add_argument("--port", type=int, default=DEFAULT_PORT, help="patrol_server 端口")
    p.add_argument("--backend", choices=["auto", "winmm", "pygame"], default="auto")
    p.add_argument("--mode", choices=["pedal", "drive", "rotate", "arcade"], default="pedal")
    p.add_argument("--invert-steer", action="store_true")
    p.add_argument("--verbose", action="store_true")
    p.add_argument("--hz", type=float, default=20.0)
    p.add_argument("--calibrate", action="store_true")
    p.add_argument("--list-devices", action="store_true")
    p.add_argument("--device-id", type=int, default=None)
    p.add_argument("--pedal-threshold", type=float, default=0.12)
    p.add_argument("--steer-threshold", type=float, default=0.06)
    p.add_argument("--pedal-direct", action="store_true")
    p.add_argument(
        "--max-linear", type=float, default=0.15,
        help="前进最大线速度 m/s（Docker cmd_vel）",
    )
    p.add_argument(
        "--max-angular", type=float, default=0.45,
        help="最大角速度 rad/s",
    )
    p.add_argument(
        "--max-lateral", type=float, default=0.12,
        help="arcade 模式横向 m/s",
    )
    p.add_argument("--min-angular", type=float, default=0.25,
                   help="rotate 模式最低角速度")
    p.add_argument(
        "--skip-ready-check", action="store_true",
        help="跳过 mission 状态检查（调试）",
    )
    p.add_argument(
        "--test-forward", action="store_true",
        help="不读 G29，发 1 秒前进测试 teleop",
    )
    args = p.parse_args()
    pedal_inv = not args.pedal_direct

    if args.list_devices:
        from logitech_g29_drive import print_device_list
        if print_device_list is None:
            print("仅 Windows 支持 --list-devices")
            sys.exit(1)
        print_device_list()
        return

    client = MissionTeleopClient(args.ip, args.port, verbose=args.verbose)

    if args.test_forward:
        print("[G29-Mission] 测试前进 vx=0.1 …")
        if not args.skip_ready_check and not client.check_ready():
            sys.exit(1)
        t0 = time.time()
        while time.time() - t0 < 1.0:
            r = client.teleop(0.1, 0, 0, duration=0.3)
            if not r.get("ok"):
                print("[G29-Mission] 失败: {0}".format(r))
                sys.exit(1)
            time.sleep(0.08)
        client.stop()
        print("[G29-Mission] 测试结束")
        return

    try:
        reader = make_reader(args.backend, args.device_id)
    except Exception as exc:
        print("初始化失败: {0}".format(exc))
        print("Windows 请试: python g29_mission_drive.py --backend winmm --calibrate")
        sys.exit(1)

    if args.calibrate:
        calibrate(reader, pedal_inv)
        return

    if not args.skip_ready_check:
        if not client.check_ready():
            sys.exit(1)

    drive_loop(reader, client, args, pedal_inv)


if __name__ == "__main__":
    main()
