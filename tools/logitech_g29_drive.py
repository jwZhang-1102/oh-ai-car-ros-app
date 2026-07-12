#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
罗技 G29 → Rosmaster TCP 6000

Windows 推荐 winmm 后端（pygame 对 G29 可能读不到轴）:
  python logitech_g29_drive.py --backend winmm --calibrate
  python logitech_g29_drive.py --backend winmm --mode pedal --ip 10.147.13.194
"""
import argparse
import socket
import sys
import time

IS_WIN = sys.platform == "win32"

try:
    import pygame
except ImportError:
    pygame = None

if IS_WIN:
    try:
        from g29_winmm import WinmmG29, list_joystick_devices, print_device_list, find_best_device_id
    except ImportError:
        WinmmG29 = None
        list_joystick_devices = None
        print_device_list = None
        find_best_device_id = None
else:
    WinmmG29 = None
    list_joystick_devices = None
    print_device_list = None
    find_best_device_id = None

# cmd 15 方向（与 App CarDirection 一致）
DIR_STOP = 0
DIR_FORWARD = 1
DIR_BACK = 2
DIR_BRAKE = 7
BTN_ESTOP = 1


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def apply_deadzone(v, deadzone=0.05):
    if abs(v) < deadzone:
        return 0.0
    sign = 1.0 if v > 0 else -1.0
    return sign * (abs(v) - deadzone) / (1.0 - deadzone)


def pedal01(axis_val, inverted=True):
    if inverted:
        return clamp((1.0 - axis_val) / 2.0, 0.0, 1.0)
    return clamp(axis_val, 0.0, 1.0)


def checksum_hex(payload):
    total = sum(int(payload[i:i + 2], 16) for i in range(0, len(payload), 2)) % 256
    return "{0:02X}".format(total)


def build_frame(cmd, info):
    # 与 App CarEncode 一致：size = info 十六进制字符数 + 2（不是字节数+2）
    body = "01" + cmd + "{0:02X}".format(len(info) + 2) + info
    return ("$" + body + checksum_hex(body) + "#").encode("ascii")


def encode_cmd10(speed_x, speed_y):
    sx = clamp(int(speed_x), -100, 100)
    sy = clamp(int(speed_y), -100, 100)
    if sx < 0:
        sx += 256
    if sy < 0:
        sy += 256
    return build_frame("10", "{0:02X}{1:02X}".format(sx, sy))


def encode_cmd15(direction):
    return build_frame("15", "{0:02X}".format(clamp(int(direction), 0, 7)))


def encode_cmd21(l1, l2, r1, r2):
    vals = [clamp(int(v), -100, 100) for v in (l1, l2, r1, r2)]
    info = "".join("{0:02X}".format(v + 256 if v < 0 else v) for v in vals)
    return build_frame("21", info)


class TcpCar(object):
    def __init__(self, host, port, verbose=False):
        self._host = host
        self._port = port
        self._sock = None
        self._verbose = verbose
        self._last_log = 0.0

    def connect(self):
        self.close()
        self._sock = socket.create_connection((self._host, self._port), timeout=3.0)
        print("[G29] TCP 已连接 {0}:{1}".format(self._host, self._port))

    def close(self):
        if self._sock is not None:
            try:
                self._sock.close()
            except OSError:
                pass
            self._sock = None

    def send(self, payload):
        if self._sock is None:
            self.connect()
        if self._verbose:
            now = time.time()
            if now - self._last_log > 0.3:
                print("[G29] TX {0}".format(payload.decode("ascii", errors="replace")))
                self._last_log = now
        try:
            self._sock.sendall(payload)
        except OSError as exc:
            print("[G29] 重连: {0}".format(exc))
            self.connect()
            self._sock.sendall(payload)

    def stop(self):
        self.send(encode_cmd15(0))
        self.send(encode_cmd10(0, 0))


def map_drive(steer, throttle, max_speed, max_turn):
    v = throttle * max_speed
    s = steer * max_turn
    left = clamp(v + s, -100, 100)
    right = clamp(v - s, -100, 100)
    return encode_cmd21(left, left, right, right)


def map_rotate(steer, max_turn, min_speed=35):
    """cmd 21 差速；带最低转速，避免 steer*max_turn 过小车不动。"""
    s = steer * max_turn
    if abs(s) < min_speed:
        s = min_speed if s > 0 else -min_speed
    s = int(s)
    left = clamp(s, -100, 100)
    right = clamp(-s, -100, 100)
    return encode_cmd21(left, left, right, right)


def map_rotate_button(steer, threshold=0.06):
    """cmd 15：5=左旋转 6=右旋转（与 App 方向键一致）。"""
    if steer > threshold:
        return encode_cmd15(6)
    if steer < -threshold:
        return encode_cmd15(5)
    return encode_cmd15(0)


def map_pedal_buttons(clutch, brake, gas, steer, pedal_threshold, steer_threshold):
    """
    G29 踏板左→右：离合、刹车、油门
      离合 → 后退 (cmd15 dir=2)
      刹车 → 停止 (cmd15 dir=0)
      油门 → 前进 (cmd15 dir=1)
    方向盘：未踩踏板时左/右旋转 (5/6)
    """
    if brake >= pedal_threshold:
        return encode_cmd15(DIR_STOP)
    if clutch >= pedal_threshold:
        return encode_cmd15(DIR_BACK)
    if gas >= pedal_threshold:
        return encode_cmd15(DIR_FORWARD)
    if abs(steer) >= steer_threshold:
        return map_rotate_button(steer, steer_threshold)
    return encode_cmd15(DIR_STOP)


def map_arcade(steer, throttle, max_speed, max_strafe):
    return encode_cmd10(int(throttle * max_speed), int(steer * max_strafe))


class PygameReader(object):
    # G29：0=方向盘 1=离合 2=油门 3=刹车（与 winmm Z/R 对应，部分设备轴序不同）
    AXIS_STEER, AXIS_CLUTCH, AXIS_GAS, AXIS_BRAKE = 0, 1, 2, 3

    def __init__(self):
        if pygame is None:
            raise RuntimeError("需要 pygame")
        import os
        os.environ.setdefault("SDL_JOYSTICK_HIDAPI", "1")
        os.environ.setdefault("SDL_JOYSTICK_HIDAPI_LOGITECH", "1")
        pygame.init()
        pygame.joystick.init()
        if pygame.joystick.get_count() == 0:
            raise RuntimeError("pygame 未检测到方向盘")
        self.joy = pygame.joystick.Joystick(0)
        self.joy.init()
        self.name = self.joy.get_name()

    def read(self, pedal_inverted=True):
        pygame.event.pump()
        steer = apply_deadzone(self.joy.get_axis(self.AXIS_STEER))
        n = self.joy.get_numaxes()
        def _ax(i):
            return self.joy.get_axis(i) if i < n else 0.0
        clutch = pedal01(_ax(self.AXIS_CLUTCH), pedal_inverted)
        brake = pedal01(_ax(self.AXIS_BRAKE), pedal_inverted)
        gas = pedal01(_ax(self.AXIS_GAS), pedal_inverted)
        estop = self.joy.get_numbuttons() > BTN_ESTOP and self.joy.get_button(BTN_ESTOP)
        raw = [_ax(i) for i in range(n)]
        return steer, clutch, brake, gas, estop, raw, 0


def make_reader(backend, device_id=None):
    if backend == "winmm":
        if not IS_WIN or WinmmG29 is None:
            raise RuntimeError("winmm 仅 Windows 可用")
        return WinmmG29(device_id)
    if backend == "pygame":
        return PygameReader()
    # auto
    if IS_WIN and WinmmG29 is not None and WinmmG29.available():
        print("[G29] 使用 winmm 后端（Windows 原生，G29 推荐）")
        return WinmmG29(device_id)
    print("[G29] 使用 pygame 后端")
    return PygameReader()


def maybe_window(title):
    if pygame is None:
        return None, None
    try:
        if not pygame.get_init():
            pygame.init()
        screen = pygame.display.set_mode((420, 150))
        pygame.display.set_caption(title)
        try:
            font = pygame.font.Font(None, 24)
        except Exception:
            font = None
        return screen, font
    except Exception:
        return None, None


def draw_status(screen, font, lines):
    if screen is None:
        return
    screen.fill((20, 30, 40))
    if font is not None:
        y = 10
        for line in lines:
            screen.blit(font.render(line, True, (220, 220, 220)), (10, y))
            y += 26
    pygame.display.flip()


def pump_quit():
    if pygame is None or not pygame.get_init():
        return True
    for event in pygame.event.get():
        if event.type in (pygame.QUIT, pygame.KEYDOWN):
            if event.type == pygame.QUIT or event.key == pygame.K_ESCAPE:
                return False
    return True


def calibrate(reader, pedal_inverted):
    screen, font = maybe_window("G29 Calibrate (winmm)")
    print("设备: {0}".format(reader.name))
    print("转动方向盘、踩油门/刹车，Ctrl+C 或 Esc 退出")
    print("若踏板无反应: --pedal-direct\n")
    try:
        while pump_quit():
            steer, clutch, brake, gas, estop, raw, btns = reader.read(pedal_inverted)
            line = (
                "raw={0} btn=0x{1:x} steer={2:+.2f} "
                "clutch={3:.2f} brake={4:.2f} gas={5:.2f}".format(
                    raw, btns, steer, clutch, brake, gas)
            )
            print(line)
            draw_status(screen, font, [
                "G29 calibrate (L->R: clutch brake gas)",
                "clutch={0:.2f} brake={1:.2f} gas={2:.2f}".format(clutch, brake, gas),
                "steer={0:+.2f}  raw={1}".format(steer, raw),
            ])
            time.sleep(0.1)
    except KeyboardInterrupt:
        pass
    print("\n标定结束")
    if pygame and pygame.get_init():
        pygame.quit()


def drive_loop(reader, car, args, pedal_inverted):
    screen, font = maybe_window("G29 Drive")
    print("[G29] mode={0} rotate_style={1} max_turn={2}".format(
        args.mode, args.rotate_style, args.max_turn))
    if args.mode == "rotate":
        print("[G29] 旋转：左打=cmd15左转(5) 右打=右转(6) 回正=停")
    elif args.mode == "pedal":
        print("[G29] 踏板 L→R: 离合=后退 刹车=停止 油门=前进")
    steer_mul = -1.0 if args.invert_steer else 1.0
    interval = 1.0 / args.hz
    last_steer_log = 0.0
    try:
        while pump_quit():
            steer, clutch, brake, gas, estop, raw, _ = reader.read(pedal_inverted)
            steer = steer * steer_mul
            throttle = gas - brake
            if estop:
                car.stop()
            elif args.mode == "pedal":
                car.send(map_pedal_buttons(
                    clutch, brake, gas, steer,
                    args.pedal_threshold, args.steer_threshold,
                ))
            elif args.mode == "rotate":
                if abs(steer) < 0.05:
                    car.stop()
                elif args.rotate_style == "button":
                    car.send(map_rotate_button(steer))
                else:
                    car.send(map_rotate(steer, args.max_turn, args.min_turn_speed))
            elif args.mode == "drive":
                if abs(throttle) < 0.02 and abs(steer) < 0.05:
                    car.stop()
                else:
                    car.send(map_drive(steer, throttle, args.max_speed, args.max_turn))
            elif args.mode == "arcade":
                if abs(throttle) < 0.02 and abs(steer) < 0.05:
                    car.stop()
                else:
                    car.send(map_arcade(steer, throttle, args.max_speed, args.max_strafe))
            draw_status(screen, font, [
                "G29 -> {0}:{1} mode={2}".format(args.ip, args.port, args.mode),
                "clutch={0:.2f} brake={1:.2f} gas={2:.2f} steer={3:+.2f}".format(
                    clutch, brake, gas, steer),
                "raw: " + str(raw),
            ])
            now = time.time()
            if args.verbose and now - last_steer_log > 0.5:
                print("[G29] steer={0:+.2f} raw0={1}".format(steer, raw[0] if raw else 0))
                last_steer_log = now
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\n[G29] 退出")
    finally:
        car.stop()
        car.close()
        if pygame and pygame.get_init():
            pygame.quit()


def main():
    p = argparse.ArgumentParser(description="Logitech G29 -> Rosmaster TCP")
    p.add_argument("--ip", default="10.147.13.194")
    p.add_argument("--port", type=int, default=6000)
    p.add_argument("--backend", choices=["auto", "winmm", "pygame"], default="auto")
    p.add_argument("--mode", choices=["drive", "arcade", "rotate", "pedal"], default="pedal",
                   help="pedal=油门前进/刹车停止(同App按键); rotate=仅方向盘")
    p.add_argument("--rotate-style", choices=["proportional", "button"],
                   default="button",
                   help="rotate 模式：button=cmd15(推荐) proportional=cmd21")
    p.add_argument("--min-turn-speed", type=int, default=40,
                   help="proportional 模式最低轮速")
    p.add_argument("--invert-steer", action="store_true", help="反转左右转向")
    p.add_argument("--verbose", action="store_true", help="打印发送的 TCP 帧")
    p.add_argument("--test-rotate", action="store_true",
                   help="不读方向盘，直接发 2 秒右旋转测试 TCP")
    p.add_argument("--max-speed", type=int, default=50)
    p.add_argument("--max-turn", type=int, default=55,
                   help="rotate/drive 转向强度，rotate 建议 40~70")
    p.add_argument("--max-strafe", type=int, default=40)
    p.add_argument("--hz", type=float, default=20.0)
    p.add_argument("--calibrate", action="store_true")
    p.add_argument("--list-devices", action="store_true", help="列出 winmm 控制器")
    p.add_argument("--device-id", type=int, default=None, help="指定 winmm 设备 id")
    p.add_argument("--pedal-threshold", type=float, default=0.12,
                   help="油门/刹车触发阈值 0~1")
    p.add_argument("--steer-threshold", type=float, default=0.06,
                   help="pedal 模式下方向盘触发转向阈值")
    p.add_argument("--pedal-direct", action="store_true")
    args = p.parse_args()
    pedal_inv = not args.pedal_direct

    if args.list_devices:
        if print_device_list is None:
            print("仅 Windows 支持 --list-devices")
            sys.exit(1)
        print_device_list()
        return

    if args.test_rotate:
        car = TcpCar(args.ip, args.port, verbose=True)
        car.connect()
        print("[G29] 测试：右旋转 cmd15=6，持续 2 秒…")
        t0 = time.time()
        while time.time() - t0 < 2.0:
            car.send(encode_cmd15(6))
            time.sleep(0.05)
        car.stop()
        car.close()
        print("[G29] 测试结束。若车未动，检查 ros/run 或换 App 试旋转键")
        return

    try:
        reader = make_reader(args.backend, args.device_id)
    except Exception as exc:
        print("初始化失败: {0}".format(exc))
        if IS_WIN:
            print("Windows 请试: python logitech_g29_drive.py --backend winmm --calibrate")
            print("并完全退出 G HUB（系统托盘右键退出）后再试")
        sys.exit(1)

    if args.calibrate:
        calibrate(reader, pedal_inv)
        return

    car = TcpCar(args.ip, args.port, verbose=args.verbose)
    car.connect()
    drive_loop(reader, car, args, pedal_inv)


if __name__ == "__main__":
    main()
