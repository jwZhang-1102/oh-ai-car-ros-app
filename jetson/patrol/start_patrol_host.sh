#!/bin/bash
# 从 Windows scp 后若脚本报错，自动去掉 CRLF 并重新执行
if grep -q $'\r' "$0" 2>/dev/null; then
  sed -i 's/\r$//' "$0" *.sh 2>/dev/null || sed -i 's/\r$//' "$0"
  exec bash "$0" "$@"
fi
# 智检哨兵：宿主机启动 HTTP + YOLO 检测（不占 6500 视频）
# 默认已与 Docker 导航并行安全（不占底盘串口）
#
# 用法:
#   bash start_patrol_host.sh                    # 前台，默认导航并行安全
#   bash start_patrol_host.sh --bg               # 后台
#   bash start_patrol_host.sh --display          # 接显示器看检测框（导航可能变卡）
#   bash start_patrol_host.sh --nav-lite --bg    # 导航仍卡顿时：CPU 轻量推理
#   bash start_patrol_host.sh --buzzer-serial    # 仅巡检单机：启用串口蜂鸣（勿与 n1 并行）
#   bash start_patrol_host.sh --mission --bg     # 导航任务：YOLO 告警自动停车+可恢复
set -e
ROOT=~/Rosmaster-App/rosmaster
cd "$ROOT"

BACKGROUND=false
DISPLAY_WIN=false
BUZZER_SERIAL=false
NAV_LITE=false
MISSION_MODE=false
for arg in "$@"; do
  case "$arg" in
    --bg) BACKGROUND=true ;;
    --display) DISPLAY_WIN=true ;;
    --buzzer-serial) BUZZER_SERIAL=true ;;
    --nav-lite) NAV_LITE=true ;;
    --mission) MISSION_MODE=true ;;
    --docker-nav)
      echo "[patrol] 提示: --docker-nav 已是默认行为，可省略"
      ;;
    *)
      echo "未知参数: $arg"
      echo "用法: bash start_patrol_host.sh [--display] [--bg] [--nav-lite] [--buzzer-serial] [--mission]"
      exit 1
      ;;
  esac
done

# 默认：导航并行 + 危险区 on-demand 位姿（不占串口、不后台轮询）
DETECTOR_ARGS=(--verbose --docker-nav --pose-on-demand)
if [ "$BUZZER_SERIAL" = true ]; then
  DETECTOR_ARGS=(--verbose --buzzer-serial)
  echo "[patrol] 单机巡检模式：启用 Rosmaster 串口蜂鸣 — 勿与 Docker 导航同时运行"
else
  echo "[patrol] 导航并行 + 危险区 on-demand（告警时才读位姿）"
fi
if [ "$BACKGROUND" = true ] && [ "$NAV_LITE" = false ] && [ "$BUZZER_SERIAL" = false ]; then
  NAV_LITE=true
  echo "[patrol] 后台模式默认启用 nav-lite（减轻负载，利于与导航并行）"
fi
if [ "$NAV_LITE" = true ]; then
  DETECTOR_ARGS+=(--nav-lite)
  echo "[patrol] nav-lite：CPU 轻量推理，减轻 Jetson 负载"
fi
if [ "$DISPLAY_WIN" = true ]; then
  DETECTOR_ARGS+=(--display)
  echo "[patrol] WARN: --display 占用 GPU/CPU，导航卡顿时请去掉 --display 或加 --nav-lite"
fi
if [ "$MISSION_MODE" = true ]; then
  DETECTOR_ARGS+=(--targets bottle --pause-nav-on-alert --alert-stop-classes bottle)
  echo "[patrol] mission 模式：仅检出 bottle → 暂停 Nav2 + 蜂鸣 + 记录事件"
  echo "[patrol] 恢复导航: curl -X POST http://127.0.0.1:6700/mission/resume"
fi

STOPPED=false

cleanup() {
  if [ "$STOPPED" = true ]; then
    return
  fi
  STOPPED=true
  echo ""
  echo "[patrol] 正在停止服务..."
  if [ -n "${SERVER_PID:-}" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
  pkill -f patrol_server.py 2>/dev/null || true
  pkill -f patrol_detector.py 2>/dev/null || true
  echo "[patrol] 已停止 patrol_server / patrol_detector"
}
trap cleanup EXIT INT TERM

echo "[patrol] 释放摄像头（若 camera_server 在跑）..."
if [ -f stop_camera_server.sh ]; then
  bash stop_camera_server.sh 2>/dev/null || true
fi

echo "[patrol] 停止旧进程..."
pkill -f patrol_server.py 2>/dev/null || true
pkill -f patrol_detector.py 2>/dev/null || true
sleep 1

if command -v docker >/dev/null 2>&1 && docker ps -q | head -1 | grep -q .; then
  if [ "$BUZZER_SERIAL" = false ]; then
    echo "[patrol] 检测到 Docker 容器在运行，已使用导航并行安全参数"
  fi
fi

if fuser /dev/myserial 2>/dev/null | grep -q .; then
  echo "[patrol] WARN: /dev/myserial 已被占用 — 导航会失效，请先停 ros/run 或旧 patrol_detector"
  fuser -v /dev/myserial 2>/dev/null || true
fi

if [ ! -f patrol_server.py ]; then
  echo "错误: 找不到 patrol_server.py，请先 scp 到 $ROOT"
  exit 1
fi
if [ ! -f patrol_detector.py ]; then
  echo "错误: 找不到 patrol_detector.py"
  exit 1
fi
if [ "$MISSION_MODE" = true ] && [ ! -f nav_mission_coordinator.py ]; then
  echo "错误: --mission 需要 nav_mission_coordinator.py"
  exit 1
fi

echo "[patrol] 启动 patrol_server :6700 ..."
nohup python3 patrol_server.py > patrol_server.log 2>&1 &
SERVER_PID=$!
sleep 1

if curl -sf http://127.0.0.1:6700/health >/dev/null; then
  echo "[patrol] patrol_server OK (PID $SERVER_PID)"
else
  echo "[patrol] patrol_server 启动失败，见 patrol_server.log"
  tail -n 20 patrol_server.log || true
  exit 1
fi

echo ""
echo "=== 巡检服务 ==="
echo "  HTTP  http://$(hostname -I | awk '{print $1}'):6700/events"
echo "  事件  tail -f events.jsonl"
echo "  截图  ls capture/patrol/"
if [ "$MISSION_MODE" = true ]; then
  echo "  任务  curl http://127.0.0.1:6700/mission/status"
  echo "  恢复  curl -X POST http://127.0.0.1:6700/mission/resume"
  echo "  终点  编辑 mission_waypoints.json 或 POST /mission/set_end"
fi
if [ -f danger_zones.json ]; then
  echo "  危险区 danger_zones.json 已加载（并行模式蜂鸣可能不可用）"
else
  echo "  提示: 无 danger_zones.json，危险区联动未启用"
fi
echo ""

if [ "$MISSION_MODE" = true ]; then
  echo "[patrol] mission: 重置任务状态（避免上次 alert_stopped 跳过蜂鸣）..."
  if curl -sf -X POST http://127.0.0.1:6700/mission/start >/dev/null; then
    echo "[patrol] mission/start OK → state=navigating"
  else
    echo "[patrol] WARN: mission/start 失败，请检查 mission_waypoints.json 或:"
    echo "         curl -X POST http://127.0.0.1:6700/mission/start"
    echo "         或 rm -f mission_state.json 后重启"
  fi
fi

if [ "$BACKGROUND" = true ]; then
  echo "[patrol] 后台启动 patrol_detector ..."
  nohup python3 -u patrol_detector.py "${DETECTOR_ARGS[@]}" >> patrol_detector.log 2>&1 &
  sleep 2
  if pgrep -f patrol_detector.py >/dev/null; then
    echo "[patrol] patrol_detector 后台 OK (PID $(pgrep -f patrol_detector.py | head -1))"
    echo "  日志  tail -f patrol_detector.log"
    trap - EXIT INT TERM
  else
    echo "[patrol] patrol_detector 启动失败:"
    tail -n 30 patrol_detector.log || true
    exit 1
  fi
else
  if [ "$DISPLAY_WIN" = true ]; then
    echo "[patrol] patrol_detector 前台 + 检测窗口（按 q 或 Ctrl+C 退出）"
  else
    echo "[patrol] patrol_detector 前台运行 — 异常 [ALERT] 将输出到本终端"
  fi
  echo "[patrol] 按 Ctrl+C 停止全部服务"
  echo ""
  python3 -u patrol_detector.py "${DETECTOR_ARGS[@]}" 2>&1 | tee -a patrol_detector.log
fi
