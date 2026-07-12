# -*- coding: utf-8 -*-
"""Windows winmm API 读取 G29（不依赖 pygame 读轴）。"""
import ctypes
from ctypes import wintypes

winmm = ctypes.windll.winmm

JOYERR_NOERROR = 0
JOY_RETURNALL = 0x000000FF

# winmm 按钮位
BTN_WINMM_1 = 0x0001


class JOYINFOEX(ctypes.Structure):
    _fields_ = [
        ("dwSize", wintypes.DWORD),
        ("dwFlags", wintypes.DWORD),
        ("dwXpos", wintypes.DWORD),
        ("dwYpos", wintypes.DWORD),
        ("dwZpos", wintypes.DWORD),
        ("dwRpos", wintypes.DWORD),
        ("dwUpos", wintypes.DWORD),
        ("dwVpos", wintypes.DWORD),
        ("dwButtons", wintypes.DWORD),
        ("dwButtonNumber", wintypes.DWORD),
        ("dwPOV", wintypes.DWORD),
        ("dwReserved1", wintypes.DWORD),
        ("dwReserved2", wintypes.DWORD),
    ]


class JOYCAPS(ctypes.Structure):
    _fields_ = [
        ("wMid", wintypes.WORD),
        ("wPid", wintypes.WORD),
        ("szPname", wintypes.WCHAR * 32),
        ("wXmin", wintypes.UINT),
        ("wXmax", wintypes.UINT),
        ("wYmin", wintypes.UINT),
        ("wYmax", wintypes.UINT),
        ("wZmin", wintypes.UINT),
        ("wZmax", wintypes.UINT),
        ("wNumButtons", wintypes.UINT),
        ("wPeriodMin", wintypes.UINT),
        ("wPeriodMax", wintypes.UINT),
        ("wRmin", wintypes.UINT),
        ("wRmax", wintypes.UINT),
        ("wUmin", wintypes.UINT),
        ("wUmax", wintypes.UINT),
        ("wVmin", wintypes.UINT),
        ("wVmax", wintypes.UINT),
        ("wCaps", wintypes.UINT),
        ("wMaxAxes", wintypes.UINT),
        ("wNumAxes", wintypes.UINT),
        ("wMaxButtons", wintypes.UINT),
        ("szRegKey", wintypes.WCHAR * 32),
        ("szOEMVxD", wintypes.WCHAR * 260),
    ]


def _norm_axis(val, center=32767.0, span=32767.0):
    return max(-1.0, min(1.0, (float(val) - center) / span))


def _pedal_from_raw(val, rest_high=True):
    """0~1 踏板深度。G29 winmm 常见：静止 65535，踩下变小。"""
    v = float(val) / 65535.0
    if rest_high:
        return max(0.0, min(1.0, 1.0 - v))
    return max(0.0, min(1.0, v))


class WinmmG29(object):
    """通过 joyGetPosEx 读 G29。"""

    def __init__(self, device_id=None):
        if device_id is None:
            device_id = find_best_device_id()
        self.device_id = device_id
        self.name = self._query_name()

    def _query_name(self):
        caps = JOYCAPS()
        err = winmm.joyGetDevCapsW(self.device_id, ctypes.byref(caps), ctypes.sizeof(caps))
        if err == JOYERR_NOERROR:
            return caps.szPname
        return "winmm joystick #{0}".format(self.device_id)

    @staticmethod
    def available():
        try:
            n = winmm.joyGetNumDevs()
            for i in range(n):
                info = JOYINFOEX()
                info.dwSize = ctypes.sizeof(JOYINFOEX)
                info.dwFlags = JOY_RETURNALL
                if winmm.joyGetPosEx(i, ctypes.byref(info)) == JOYERR_NOERROR:
                    return True
            return False
        except Exception:
            return False

    def read_raw(self):
        info = JOYINFOEX()
        info.dwSize = ctypes.sizeof(JOYINFOEX)
        info.dwFlags = JOY_RETURNALL
        err = winmm.joyGetPosEx(self.device_id, ctypes.byref(info))
        if err != JOYERR_NOERROR:
            raise RuntimeError("joyGetPosEx 失败 err={0}".format(err))
        return info

    def read(self, pedal_inverted=True):
        """
        G29 winmm 踏板（左→右）:
          dwYpos = 离合
          dwRpos = 刹车（中）
          dwZpos = 油门（右）
        """
        info = self.read_raw()
        steer = _norm_axis(info.dwXpos)
        if abs(steer) < 0.05:
            steer = 0.0
        rest_high = pedal_inverted
        clutch = _pedal_from_raw(info.dwYpos, rest_high)
        brake = _pedal_from_raw(info.dwRpos, rest_high)
        gas = _pedal_from_raw(info.dwZpos, rest_high)
        estop = bool(info.dwButtons & BTN_WINMM_1)
        raw = [info.dwXpos, info.dwYpos, info.dwZpos, info.dwRpos]
        return steer, clutch, brake, gas, estop, raw, info.dwButtons


def _read_raw_id(device_id):
    info = JOYINFOEX()
    info.dwSize = ctypes.sizeof(JOYINFOEX)
    info.dwFlags = JOY_RETURNALL
    err = winmm.joyGetPosEx(device_id, ctypes.byref(info))
    if err != JOYERR_NOERROR:
        return None
    return info


def list_joystick_devices():
    """列出 winmm 可见的所有游戏控制器。"""
    devices = []
    try:
        n = winmm.joyGetNumDevs()
    except Exception:
        return devices
    for i in range(n):
        caps = JOYCAPS()
        err = winmm.joyGetDevCapsW(i, ctypes.byref(caps), ctypes.sizeof(caps))
        if err != JOYERR_NOERROR:
            continue
        info = _read_raw_id(i)
        raw = None
        if info is not None:
            raw = [info.dwXpos, info.dwYpos, info.dwZpos, info.dwRpos]
        devices.append({
            "id": i,
            "name": caps.szPname,
            "buttons": caps.wNumButtons,
            "axes": caps.wNumAxes,
            "raw": raw,
        })
    return devices


def find_best_device_id(prefer_id=None):
    if prefer_id is not None:
        return prefer_id
    devices = list_joystick_devices()
    if not devices:
        return 0
    keywords = ("g29", "logitech", "driving force", "driving", "race")
    for d in devices:
        low = d["name"].lower()
        if any(k in low for k in keywords):
            return d["id"]
    return devices[0]["id"]


def print_device_list():
    devices = list_joystick_devices()
    if not devices:
        print("winmm 未找到任何游戏控制器")
        return
    print("winmm 游戏控制器列表:")
    for d in devices:
        print("  id={0}  axes={1}  buttons={2}".format(d["id"], d["axes"], d["buttons"]))
        print("       name: {0}".format(d["name"]))
        print("       raw:  {0}".format(d["raw"]))
    print("\n若 name 不含 G29/Logitech，或 raw 全 32767 且不随操作变化，")
    print("请打开 Windows  joy.cpl  测试轴是否动（见 tools/README.md）")
