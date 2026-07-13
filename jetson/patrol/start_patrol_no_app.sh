#!/bin/bash
# 无 App 模式：仅启动 YOLO 巡检 + 危险区联动（不启 HTTP 6700，省资源）
#
# 与 Docker 导航并行（推荐流程）：
#   1) 容器内: n1 → n2 → n3，RViz 设 2D Pose Estimate
#   2) RViz 2D Goal Pose 点到危险区中心（或途经危险区）
#   3) 宿主机: bash start_patrol_no_app.sh --bg
#
# 用法:
#   bash start_patrol_no_app.sh              # 前台，看 [ALERT]/[DANGER] 日志
#   bash start_patrol_no_app.sh --bg           # 后台（默认 nav-lite）
#   bash start_patrol_no_app.sh --nav-lite     # 导航仍卡时：CPU + 小分辨率
#   bash start_patrol_no_app.sh --print-goals  # 打印危险区中心坐标，供 RViz 设 Goal
#   bash start_danger_lidar.sh --bg            # 方案一：激光检测人在危险区（更省算力）
set -e
ROOT=~/Rosmaster-App/rosmaster
cd "$ROOT"

BACKGROUND=false
NAV_LITE=false
PRINT_GOALS=false
for arg in "$@"; do
  case "$arg" in
    --bg) BACKGROUND=true ;;
    --nav-lite) NAV_LITE=true ;;
    --print-goals) PRINT_GOALS=true ;;
    *)
      echo "未知参数: $arg"
      echo "用法: bash start_patrol_no_app.sh [--bg] [--nav-lite] [--print-goals]"
      exit 1
      ;;
  esac
done

if [ "$PRINT_GOALS" = true ]; then
  python3 - <<'PY'
import json
from pathlib import Path

p = Path("danger_zones.json")
if not p.is_file():
    print("无 danger_zones.json")
    raise SystemExit(1)
data = json.loads(p.read_text(encoding="utf-8"))
print(f"frame: {data.get('frame', 'map')}")
for z in data.get("zones", []):
    pts = z.get("points", [])
    if len(pts) < 3:
        continue
    xs = [float(p[0]) for p in pts]
    ys = [float(p[1]) for p in pts]
    cx = sum(xs) / len(xs)
    cy = sum(ys) / len(ys)
    print(f"  {z.get('name', 'zone')}: 中心约 ({cx:.3f}, {cy:.3f})")
    print(f"    → RViz 2D Goal Pose 点到这里，小车会导航进危险区")
PY
  exit 0
fi

if [ "$BACKGROUND" = true ] && [ "$NAV_LITE" = false ]; then
  NAV_LITE=true
  echo "[no-app] 后台模式默认 nav-lite"
fi

DETECTOR_ARGS=(--verbose --docker-nav --pose-on-demand)
if [ "$NAV_LITE" = true ]; then
  DETECTOR_ARGS+=(--nav-lite)
  echo "[no-app] nav-lite: CPU 推理 + 256 分辨率"
fi

echo "[no-app] 不启动 patrol_server（无 App 不需要 6700）"
echo "[no-app] 导航并行 + 危险区 on-demand 位姿"

if [ -f stop_camera_server.sh ]; then
  bash stop_camera_server.sh 2>/dev/null || true
fi
pkill -f patrol_detector.py 2>/dev/null || true
sleep 1

if fuser /dev/myserial 2>/dev/null | grep -q .; then
  echo "[no-app] WARN: /dev/myserial 被占用 — 确认是 Docker n1，而非 ros/run"
  fuser -v /dev/myserial 2>/dev/null || true
fi

if [ ! -f patrol_detector.py ]; then
  echo "错误: 找不到 patrol_detector.py"
  exit 1
fi

if [ -f danger_zones.json ]; then
  echo "[no-app] 危险区已配置: danger_zones.json"
  bash "$0" --print-goals 2>/dev/null || true
else
  echo "[no-app] WARN: 无 danger_zones.json，仅 person 检测，无地理围栏"
fi

echo ""
echo "=== 无 App 巡检 ==="
echo "  日志  tail -f patrol_detector.log"
echo "  事件  tail -f events.jsonl"
echo "  截图  ls capture/patrol/"
echo "  [DANGER] = 车在危险区 + 检出 person"
echo ""

if [ "$BACKGROUND" = true ]; then
  nohup python3 -u patrol_detector.py "${DETECTOR_ARGS[@]}" >> patrol_detector.log 2>&1 &
  sleep 2
  if pgrep -f patrol_detector.py >/dev/null; then
    echo "[no-app] patrol_detector 后台 OK (PID $(pgrep -f patrol_detector.py | head -1))"
  else
    tail -n 30 patrol_detector.log || true
    exit 1
  fi
else
  python3 -u patrol_detector.py "${DETECTOR_ARGS[@]}" 2>&1 | tee -a patrol_detector.log
fi
