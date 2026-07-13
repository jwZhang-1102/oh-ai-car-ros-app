#!/bin/bash
# 停止宿主机巡检进程
pkill -f patrol_server.py 2>/dev/null || true
pkill -f patrol_detector.py 2>/dev/null || true
pkill -f danger_zone_lidar.py 2>/dev/null || true
echo "已停止 patrol_server / patrol_detector / danger_zone_lidar"
