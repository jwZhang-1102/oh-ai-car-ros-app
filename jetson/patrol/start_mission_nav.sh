#!/bin/bash
# 从 Windows scp 后若报 set: pipefail 无效，自动去掉 CRLF 并重新执行
if grep -q $'\r' "$0" 2>/dev/null; then
  sed -i 's/\r$//' "$0" *.sh 2>/dev/null || sed -i 's/\r$//' "$0"
  exec bash "$0" "$@"
fi
# 一键启动「自主导航 + 巡检 + 告警停车」任务模式（不改 App）
#
# 前置：Docker 导航 n1+n3 已启动，RViz 已 2D Pose Estimate
#
# 用法:
#   bash start_mission_nav.sh
#   bash start_mission_nav.sh --display          # 前台+检测窗口（绿框）
#   bash start_mission_nav.sh --set-end 1.5 2.0 0.0   # 设置终点后启动
set -eu
ROOT=~/Rosmaster-App/rosmaster
cd "$ROOT"

SET_END=false
DISPLAY_WIN=false
END_X=""
END_Y=""
END_YAW="0"

for arg in "$@"; do
  case "$arg" in
    --set-end)
      SET_END=true
      ;;
    --display)
      DISPLAY_WIN=true
      ;;
    -h|--help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *)
      if [ "$SET_END" = true ] && [ -z "$END_X" ]; then
        END_X="$arg"
      elif [ "$SET_END" = true ] && [ -z "$END_Y" ]; then
        END_Y="$arg"
      elif [ "$SET_END" = true ]; then
        END_YAW="$arg"
        SET_END=false
      else
        echo "未知参数: $arg"
        exit 1
      fi
      ;;
  esac
done

if [ -n "$END_X" ] && [ -n "$END_Y" ]; then
  echo "[mission] 设置终点 ($END_X, $END_Y, yaw=$END_YAW)"
  curl -sf -X POST http://127.0.0.1:6700/mission/set_end \
    -H "Content-Type: application/json" \
    -d "{\"x\":$END_X,\"y\":$END_Y,\"yaw\":$END_YAW}" 2>/dev/null \
    || python3 - <<PY
import json
from pathlib import Path
p = Path("mission_waypoints.json")
data = {"frame_id": "map", "end": {"x": float("$END_X"), "y": float("$END_Y"), "yaw": float("$END_YAW")}}
p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("[mission] 已写入 mission_waypoints.json")
PY
fi

if ! docker ps -q | head -1 | grep -q .; then
  echo "[mission] WARN: 未检测到运行中的 Docker 容器，请先 n1/n3"
fi

PATROL_ARGS=(--mission)
if [ "$DISPLAY_WIN" = true ]; then
  PATROL_ARGS+=(--display)
  echo "[mission] display 模式：前台显示检测窗口（需 NoMachine 桌面）"
else
  PATROL_ARGS+=(--bg)
  echo "[mission] 后台模式：默认 GPU 推理，终端实时显示 patrol_detector.log"
fi

# mission/start 已在 start_patrol_host.sh 内执行（display 前台模式也会跑到）
bash start_patrol_host.sh "${PATROL_ARGS[@]}"

echo ""
echo "=========================================="
echo "  导航任务模式已启动"
echo "------------------------------------------"
echo "  1. RViz: 2D Pose Estimate → 2D Goal Pose"
echo "  2. RViz: 2D Goal Pose 设终点"
echo "  3. 记录终点: bash capture_end_goal.sh"
echo "  4. 路上放瓶子 → 自动停车 + 蜂鸣 + events.jsonl"
echo "  4. 人工绕障:"
echo "       Windows: python tools/g29_mission_drive.py --backend winmm --ip <小车IP>"
echo "       或 curl -X POST http://127.0.0.1:6700/mission/teleop \\"
echo "         -H 'Content-Type: application/json' \\"
echo "         -d '{\"vx\":0.15,\"vy\":0,\"wz\":0}'"
echo "  5. 绕障后恢复:"
echo "       curl -X POST http://127.0.0.1:6700/mission/resume"
echo "  状态: curl http://127.0.0.1:6700/mission/status"
echo "=========================================="
