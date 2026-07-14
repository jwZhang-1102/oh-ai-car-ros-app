#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
与 Yahboom app.py 配套：只启动巡检 HTTP :6700（App「智能巡检」）。

不占摄像头、不抢串口；可与 app.py（6000/6500）同时跑。
底层复用同目录 patrol_server.py。

用法（Jetson）:
  cd ~/Rosmaster-App/rosmaster
  python3 app2.py

由 start_app.sh / run 拉起时与 app.py 并行即可。
"""
from __future__ import print_function

import os
import sys

# 保证可从任意 cwd 找到同目录模块
ROOT = os.path.dirname(os.path.abspath(__file__))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)
os.chdir(ROOT)


def main():
    try:
        import patrol_server as ps
    except ImportError as e:
        print("[app2] 找不到 patrol_server.py，请放在同目录: {0}".format(ROOT))
        print("[app2] {0}".format(e))
        sys.exit(1)

    ps.PATROL_DIR.mkdir(parents=True, exist_ok=True)
    print("[app2] Patrol HTTP :{0}  (与 app.py 的 6000/6500 并行)".format(ps.PORT))
    print("[app2]   GET  http://0.0.0.0:{0}/events".format(ps.PORT))
    print("[app2]   GET  http://0.0.0.0:{0}/health".format(ps.PORT))
    print("[app2] 不启动 YOLO；新告警仍需 start_patrol_host.sh 或单独跑 detector")
    ps.app.run(host="0.0.0.0", port=ps.PORT, threaded=True, use_reloader=False)


if __name__ == "__main__":
    main()
