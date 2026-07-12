#!/bin/bash
# 并行 A/B 对比：单独导航 vs 导航+巡检，定位冲突类型
# 用法: cd ~/Rosmaster-App/rosmaster && bash verify_parallel_ab.sh
set -e
ROOT=~/Rosmaster-App/rosmaster
cd "$ROOT"

CID=$(docker ps -q 2>/dev/null | head -1)

echo "=========================================="
echo "  并行冲突 A/B 诊断（导航 + 巡检）"
echo "=========================================="
echo ""
echo "前提: 容器内 n1+n2+n3 已跑，RViz 已 2D Pose Estimate"
echo ""

echo "【1】宿主机串口（并行最常见根因）"
if [ -e /dev/myserial ]; then
  if OUT=$(fuser /dev/myserial 2>/dev/null); then
    echo "  FAIL  /dev/myserial 被占用: $OUT"
    fuser -v /dev/myserial 2>/dev/null || true
    echo "  → 停 patrol / ros/run，或用新版 start_patrol_host.sh（默认不占串口）"
  else
    echo "  OK    /dev/myserial 空闲"
  fi
else
  echo "  SKIP  无 /dev/myserial"
fi

echo ""
echo "【2】巡检进程与日志"
if pgrep -f patrol_detector.py >/dev/null; then
  echo "  RUN   patrol_detector PID=$(pgrep -f patrol_detector.py | head -1)"
  grep -E 'Rosmaster Serial|Docker 并行|nav-lite|skip-pose|位姿 backend' patrol_detector.log 2>/dev/null | tail -5 || true
  if grep -q 'Rosmaster Serial' patrol_detector.log 2>/dev/null; then
    echo "  FAIL  日志含 Rosmaster Serial → 旧版或 --buzzer-serial，会抢导航串口"
  fi
else
  echo "  STOP  patrol_detector 未运行"
fi

echo ""
echo "【3】容器 cmd_vel（导航+巡检同时跑时执行）"
if [ -z "$CID" ]; then
  echo "  SKIP  无 Docker 容器"
else
  docker exec "$CID" bash -lc '
    echo "  设 Goal 后 5 秒内 cmd_vel 频率:"
    timeout 5 ros2 topic hz /cmd_vel --window 5 2>/dev/null || echo "  WARN 无 cmd_vel 或超时"
  ' || echo "  docker exec 失败"
fi

echo ""
echo "=========================================="
echo "  A/B 对比步骤（请人工做并记录）"
echo "=========================================="
cat <<'EOF'

A. 仅导航（宿主机不跑 patrol）
   → RViz 2D Goal Pose，车能走到终点？  [是/否]

B. 导航 + 仅 HTTP（不起 YOLO）
   pkill -f patrol_detector
   nohup python3 patrol_server.py > patrol_server.log 2>&1 &
   → 再设 Goal，能走？  [是/否]
   否 → 异常；是 → 问题在 patrol_detector

C. 导航 + 最简 YOLO（不占串口、不读位姿）
   pkill -f patrol_detector
   python3 -u patrol_detector.py --no-zones --no-buzzer --verbose &
   → 再设 Goal，能走？  [是/否]
   否 → YOLO 算力/GPU 争用，用: bash start_patrol_host.sh --nav-lite --bg

D. 导航 + 正式巡检
   pkill -f patrol_detector
   bash start_patrol_host.sh --bg
   → 再设 Goal，能走？  [是/否]
   否 → 试: python3 patrol_detector.py --docker-nav --skip-pose --nav-lite --verbose &

判定:
  A是 B否     → unlikely
  A是 C否     → Jetson 负载：--nav-lite / 关 --display
  A是 D否 C是 → 危险区 docker 位姿轮询：--skip-pose 或 --pose-poll 10
  A是 D否 C否 → 串口或旧脚本：fuser /dev/myserial + 更新 scp 文件

EOF
