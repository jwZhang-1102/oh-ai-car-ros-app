#!/bin/bash
# 危险区联动自检：位姿 / 多边形 / 蜂鸣器
# 用法: cd ~/Rosmaster-App/rosmaster && bash verify_danger_link.sh
set -e
ROOT=~/Rosmaster-App/rosmaster
cd "$ROOT"

echo "========== 1. 文件检查 =========="
for f in danger_zones.json danger_zone_utils.py pose_reader.py rosmaster_buzzer.py patrol_detector.py danger_zone_lidar.py lidar_scan_utils.py; do
  if [ -f "$f" ]; then
    echo "  OK  $f"
  else
    echo "  缺失 $f  ← 请 scp 上传"
  fi
done

echo ""
echo "========== 2. 多边形判断（本地 Python） =========="
python3 - <<'PY'
from pathlib import Path
import sys
sys.path.insert(0, ".")
from danger_zone_utils import load_danger_zones, find_zone_at

p = Path("danger_zones.json")
if not p.is_file():
    print("  跳过: 无 danger_zones.json")
else:
    _, zones = load_danger_zones(p)
    # 取第一个 zone 顶点均值附近作为「区内」测试点
    pts = zones[0].points
    cx = sum(x for x, _ in pts) / len(pts)
    cy = sum(y for _, y in pts) / len(pts)
    inside = find_zone_at(cx, cy, zones)
    outside = find_zone_at(0.0, 0.0, zones)
    print(f"  区名: {zones[0].name}")
    print(f"  中心点 ({cx:.2f},{cy:.2f}) 在区内: {inside is not None}")
    print(f"  原点 (0,0) 在区内: {outside is not None}")
PY

echo ""
echo "========== 3. /amcl_pose 位姿（需 Docker n1 导航已启动） =========="
CID=""
if command -v docker >/dev/null 2>&1; then
  CID=$(docker ps --format '{{.ID}}' | head -1)
fi

if command -v ros2 >/dev/null 2>&1; then
  if ros2 topic list 2>/dev/null | grep -q amcl_pose; then
    echo "  [宿主机 ros2] 等待 /amcl_pose（最多 8 秒）..."
    timeout 8 ros2 topic echo /amcl_pose --once 2>/dev/null || echo "  超时: RViz 2D Pose Estimate"
  else
    echo "  宿主机未找到 /amcl_pose"
  fi
elif [ -n "$CID" ]; then
  echo "  宿主机无 ros2，改用 docker exec 容器 ${CID:0:12} ..."
  if docker exec "$CID" bash -lc "ros2 topic list 2>/dev/null" | grep -q amcl_pose; then
    echo "  容器内话题 OK，读取一条:"
    docker exec "$CID" bash -lc "timeout 8 ros2 topic echo /amcl_pose --once 2>/dev/null" \
      || echo "  超时: 请容器内 n1 + RViz 2D Pose Estimate"
  else
    echo "  容器内无 /amcl_pose → 请先运行 n1（+ n3）"
    echo "  容器内 pose 相关话题:"
    docker exec "$CID" bash -lc "ros2 topic list 2>/dev/null | grep -Ei 'pose|amcl'" | head -10 || true
  fi
else
  echo "  无 ros2 且无运行中 Docker 容器"
fi

python3 - <<'PY'
import sys
sys.path.insert(0, ".")
try:
    from pose_reader import find_nav_container, parse_amcl_echo, AmclPoseReader
    cid = find_nav_container()
    print(f"  pose_reader 自动容器: {cid[:12] if cid else '无'}")
    r = AmclPoseReader(backend="docker")
    r.start()
    import time
    time.sleep(3)
    p = r.get_pose()
    r.stop()
    if p:
        print(f"  pose_reader OK: x={p.x:.2f} y={p.y:.2f} yaw={p.yaw:.2f}")
    else:
        print(f"  pose_reader 暂无位姿: {r.error}")
except Exception as e:
    print(f"  pose_reader 测试跳过: {e}")
PY

echo ""
echo "========== 4. 蜂鸣器（500ms 测试） =========="
python3 - <<'PY'
import sys
sys.path.insert(0, ".")
from rosmaster_buzzer import BuzzerController, encode_buzzer_tcp

print("  TCP 帧(500ms):", encode_buzzer_tcp(500).decode())
b = BuzzerController()
backend = "Rosmaster_Lib" if b.available else "TCP:6000"
print(f"  backend={backend}")
ok = b.beep(500)
print(f"  beep(500) -> {'成功（应听到短响）' if ok else '失败'}")
if not ok:
    print("  提示: 先运行 ros/run 或确保 TCP 6000 在线: ss -tlnp | grep 6000")
PY

echo ""
echo "========== 5. 服务端口 =========="
ss -tlnp 2>/dev/null | grep -E ':6000|:6700' || netstat -tlnp 2>/dev/null | grep -E ':6000|:6700' || echo "  6000/6700 均未监听"

echo ""
echo "========== 6. 激光 /scan（方案一，需 n1） =========="
if [ -n "$CID" ]; then
  if docker exec "$CID" bash -lc "ros2 topic list 2>/dev/null" | grep -qx "/scan"; then
    echo "  容器内 /scan 话题 OK"
    python3 - <<'PY'
import sys
sys.path.insert(0, ".")
from lidar_scan_utils import fetch_docker_scan_once
s = fetch_docker_scan_once()
if s:
    print(f"  读取一帧 scan OK: ranges={len(s.ranges)}")
else:
    print("  读取 scan 失败（n1 是否已启动？）")
PY
  else
    echo "  容器内无 /scan → 请先 n1"
  fi
else
  echo "  跳过: 无 Docker 容器"
fi

echo ""
echo "========== 完成 =========="
echo "YOLO 危险区: bash start_patrol_host.sh"
echo "激光人在危险区: bash start_danger_lidar.sh --bg"
