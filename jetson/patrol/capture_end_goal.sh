#!/bin/bash
# RViz 点完 2D Goal Pose 后，抓取终点坐标写入 mission（供 resume 用）
#
# 用法:
#   bash capture_end_goal.sh
#   bash capture_end_goal.sh --wait 60   # 60 秒内点 Goal 也行
set -euo pipefail
ROOT=~/Rosmaster-App/rosmaster
cd "$ROOT"
python3 capture_end_goal.py "$@"
