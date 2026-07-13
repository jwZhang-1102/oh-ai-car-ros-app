#!/bin/bash
# 方案一：激光雷达危险区检测（人在危险区）— 与 Docker 导航并行，无 App / 无 YOLO
#
# 前置:
#   容器内 n1 → n2 → n3，RViz 2D Pose Estimate
#   danger_zones.json 已标定
#
# 用法:
#   bash start_danger_lidar.sh           # 前台
#   bash start_danger_lidar.sh --bg      # 后台（推荐）
#   bash start_danger_lidar.sh --poll 1.5  # 降低 docker 读取频率
set -e
ROOT=~/Rosmaster-App/rosmaster
cd "$ROOT"

BACKGROUND=false
PY_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --bg) BACKGROUND=true ;;
    *) PY_ARGS+=("$arg") ;;
  esac
done

for f in danger_zone_lidar.py lidar_scan_utils.py danger_zone_utils.py pose_reader.py rosmaster_buzzer.py; do
  if [ ! -f "$f" ]; then
    echo "错误: 缺少 $f，请先 scp 上传 jetson/patrol/ 下文件"
    exit 1
  fi
done

if [ ! -f danger_zones.json ]; then
  echo "错误: 缺少 danger_zones.json（RViz 标定危险区）"
  exit 1
fi

pkill -f danger_zone_lidar.py 2>/dev/null || true
sleep 1

if fuser /dev/myserial 2>/dev/null | grep -q .; then
  echo "[lidar] /dev/myserial 已占用 — 应为 Docker n1（正常）"
else
  echo "[lidar] WARN: 串口未占用，请先容器内 n1"
fi

echo "[lidar] 方案一：激光 + map 危险区（人在区内才告警）"
echo "[lidar] 不占摄像头、不占 YOLO 算力"
echo "  日志  tail -f danger_zone_lidar.log"
echo "  事件  tail -f events.jsonl"
echo ""

if [ "$BACKGROUND" = true ]; then
  nohup python3 -u danger_zone_lidar.py --verbose "${PY_ARGS[@]}" >> danger_zone_lidar.log 2>&1 &
  sleep 2
  if pgrep -f danger_zone_lidar.py >/dev/null; then
    echo "[lidar] danger_zone_lidar 后台 OK (PID $(pgrep -f danger_zone_lidar.py | head -1))"
  else
    tail -n 30 danger_zone_lidar.log || true
    exit 1
  fi
else
  python3 -u danger_zone_lidar.py --verbose "${PY_ARGS[@]}" 2>&1 | tee -a danger_zone_lidar.log
fi
