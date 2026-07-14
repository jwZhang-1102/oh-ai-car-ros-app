#!/bin/bash
# 仅启动巡检 HTTP :6700（给 App「智能巡检」拉事件/截图）
# 不启 YOLO，不占摄像头 → 可与 ros/run 的 6000/6500 同时开。
#
# 用法:
#   bash start_patrol_http.sh
# 挂到 Yahboom run 末尾（在 Jetson 的 run 脚本最后加一行）:
#   bash "$HOME/Rosmaster-App/rosmaster/start_patrol_http.sh" || true
#
set -e
ROOT=~/Rosmaster-App/rosmaster
cd "$ROOT"

if [ ! -f patrol_server.py ]; then
  echo "[patrol-http] 缺少 patrol_server.py，请先 scp 到 $ROOT"
  exit 1
fi

if curl -sf http://127.0.0.1:6700/health >/dev/null 2>&1; then
  echo "[patrol-http] 6700 已在运行，跳过启动"
  exit 0
fi

pkill -f patrol_server.py 2>/dev/null || true
sleep 0.3
nohup python3 patrol_server.py > patrol_server.log 2>&1 &
sleep 1

if curl -sf http://127.0.0.1:6700/health >/dev/null; then
  IP=$(hostname -I | awk '{print $1}')
  echo "[patrol-http] OK → http://${IP}:6700/events"
else
  echo "[patrol-http] 启动失败，见 $ROOT/patrol_server.log"
  tail -n 15 patrol_server.log 2>/dev/null || true
  exit 1
fi
