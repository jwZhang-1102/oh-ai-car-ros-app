#!/bin/bash
# G29 模拟驾驶：低延迟 MJPEG（6501）
#
# 重要：先停 ros/run（另终端 Ctrl+C），再启本脚本；6501 成功后再 ros/run
#
# 用法:
#   bash start_low_latency_video.sh           # 默认 320x240 流畅
#   bash start_low_latency_video.sh --hd      # 640x480 更清晰
#   bash start_low_latency_video.sh --bg      # 后台
#   bash start_low_latency_video.sh --hd --bg
set -e
ROOT=~/Rosmaster-App/rosmaster
cd "$ROOT"

BACKGROUND=false
HD=false
for arg in "$@"; do
  case "$arg" in
    --bg) BACKGROUND=true ;;
    --hd) HD=true ;;
    *)
      echo "用法: bash start_low_latency_video.sh [--hd] [--bg]"
      exit 1
      ;;
  esac
done

if [ "$HD" = true ]; then
  WIDTH=640
  HEIGHT=480
  FPS=15
  QUALITY=70
  echo "[video] 档位: HD 640x480 q=70"
else
  WIDTH=320
  HEIGHT=240
  FPS=15
  QUALITY=60
  echo "[video] 档位: 流畅 320x240 q=60"
fi

wait_camera_free() {
  local i
  for i in $(seq 1 12); do
    if ! fuser /dev/video0 >/dev/null 2>&1; then
      return 0
    fi
    echo "[video] /dev/video0 占用中，等待释放 (${i}/12)..."
    fuser -v /dev/video0 2>/dev/null || true
    sleep 1
  done
  echo "[video] 错误: /dev/video0 仍被占用，无法启动低延迟视频"
  echo "  请执行:"
  echo "    1) 所有终端 Ctrl+C 停掉 low_latency_mjpeg / ros/run"
  echo "    2) bash stop_camera_server.sh && bash stop_patrol_host.sh"
  echo "    3) pkill -f low_latency_mjpeg.py"
  echo "    4) fuser -v /dev/video0"
  fuser -v /dev/video0 2>/dev/null || true
  exit 1
}

echo "[video] 释放摄像头..."
bash stop_patrol_host.sh 2>/dev/null || true
bash stop_camera_server.sh 2>/dev/null || true
pkill -f low_latency_mjpeg.py 2>/dev/null || true
sleep 2
wait_camera_free

if [ ! -f low_latency_mjpeg.py ]; then
  echo "错误: 找不到 low_latency_mjpeg.py"
  exit 1
fi

v4l2-ctl -d /dev/video0 --set-fmt-video=width=${WIDTH},height=${HEIGHT},pixelformat=MJPG
v4l2-ctl -d /dev/video0 --set-parm=${FPS}

ARGS=(--v4l2-setup --width "${WIDTH}" --height "${HEIGHT}" --fps "${FPS}" --quality "${QUALITY}" --port 6501)

if [ "$BACKGROUND" = true ]; then
  nohup python3 -u low_latency_mjpeg.py "${ARGS[@]}" >> low_latency_video.log 2>&1 &
  sleep 2
  if ! pgrep -f low_latency_mjpeg.py >/dev/null; then
    echo "[video] 启动失败:"
    tail -n 30 low_latency_video.log || true
    exit 1
  fi
  if curl -sf http://127.0.0.1:6501/health | grep -q '"has_frame": true'; then
    echo "[video] 后台 OK（已有画面）→ http://$(hostname -I | awk '{print $1}'):6501/video_feed"
  else
    echo "[video] 进程在跑但尚无画面，查日志: tail -f low_latency_video.log"
  fi
else
  echo "[video] 前台 → http://127.0.0.1:6501/video_feed"
  echo "[video] 看到 camera OK 后，另开终端执行 ros/run（G29 控车）"
  python3 -u low_latency_mjpeg.py "${ARGS[@]}"
fi
