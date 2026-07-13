#!/bin/bash
# 导航并行 + 瓶子巡检告警（不停车、不用 mission）
#
# 用法:
#   bash start_patrol_bottle.sh
#
# 前置: 容器内 n1/n2/n3 已启动，RViz 已 2D Pose Estimate
# 停止: bash stop_patrol_host.sh
set -eu
ROOT=~/Rosmaster-App/rosmaster
cd "$ROOT"
exec bash start_patrol_host.sh --bottle-only --bg "$@"
