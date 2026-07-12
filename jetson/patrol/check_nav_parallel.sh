#!/bin/bash
# 诊断：Docker 导航 + 巡检 能否并行
# 用法: cd ~/Rosmaster-App/rosmaster && bash check_nav_parallel.sh
set -e
ROOT=~/Rosmaster-App/rosmaster
cd "$ROOT"

echo "========== 1. 底盘串口 =========="
if [ -e /dev/myserial ]; then
  echo "  /dev/myserial 存在"
  if fuser /dev/myserial 2>/dev/null; then
    echo "  ^ 已被占用 — Docker n1 无法控制底盘，导航必失效"
    fuser -v /dev/myserial 2>/dev/null || true
  else
    echo "  未被占用 OK"
  fi
else
  echo "  无 /dev/myserial（可能在容器内映射）"
fi

echo ""
echo "========== 2. 宿主机控车/巡检进程 =========="
ps aux | grep -E 'ros/run|patrol_detector|Rosmaster|camera_server' | grep -v grep || echo "  无相关进程"

echo ""
echo "========== 3. TCP 6000（与 Docker 导航冲突） =========="
ss -tlnp 2>/dev/null | grep ':6000' || echo "  6000 未监听 OK"

echo ""
echo "========== 4. Docker 导航话题（需 n1 已启动） =========="
CID=$(docker ps -q | head -1)
if [ -z "$CID" ]; then
  echo "  无运行中容器 — 请先 docker start + n1"
else
  echo "  容器 ${CID:0:12}"
  docker exec "$CID" bash -lc '
    for t in /scan /odom /cmd_vel /amcl_pose; do
      if ros2 topic list 2>/dev/null | grep -qx "$t"; then
        echo "  OK $t"
      else
        echo "  MISS $t"
      fi
    done
    echo "  cmd_vel 发布者:"
    ros2 topic info /cmd_vel 2>/dev/null | grep "Publisher" || true
  ' || echo "  docker exec 失败"
fi

echo ""
echo "========== 5. patrol_detector 日志关键字 =========="
if [ -f patrol_detector.log ]; then
  grep -E 'Rosmaster Serial|docker-nav|Docker 并行|位姿 backend|WARN' patrol_detector.log | tail -8 || true
else
  echo "  无 patrol_detector.log"
fi

echo ""
echo "========== 建议 =========="
echo "  仅导航: 容器 n1→n2→n3，宿主机不跑 patrol"
echo "  导航+巡检: bash start_patrol_host.sh --bg  （默认已导航安全）"
echo "  仍不走: bash start_patrol_host.sh --nav-lite --bg"
echo "  仍不走: 先 stop 全部 patrol，确认单独 n3 能走，再逐步加巡检"
