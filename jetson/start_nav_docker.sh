#!/bin/bash
# 一键启动 Docker 自主导航：docker start → 三个终端分别 n1 / n2 / n3
#
# 用法（在 Jetson 宿主机 ~/Rosmaster-App/rosmaster/ 或任意目录）:
#   bash start_nav_docker.sh              # 默认：先 n1，等 15s 开 n2，再等 5s 开 n3
#   bash start_nav_docker.sh --nowait     # 三个终端同时开（需自己确认 n1 就绪后再 n3）
#   bash start_nav_docker.sh --tmux       # 无桌面时用 tmux 开 3 窗
#   NAV_DOCKER_CID=2169 bash start_nav_docker.sh   # 指定容器 ID 前缀
#
# 依赖：~/.bashrc 里已配置 s/d/n1/n2/n3（Yahboom 手册默认）
# 若无别名，脚本会回退到完整 ros2 launch 命令。
set -euo pipefail

WAIT_STAGGER=true
USE_TMUX=false
N1_DELAY=15
N2_DELAY=5

for arg in "$@"; do
  case "$arg" in
    --nowait) WAIT_STAGGER=false ;;
    --tmux) USE_TMUX=true ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "未知参数: $arg （可用 --nowait / --tmux）"
      exit 1
      ;;
  esac
done

# 完整命令（容器内无 n1/n2/n3 别名时用）
N1_LAUNCH="${N1_LAUNCH:-ros2 launch yahboomcar_nav laser_bringup_launch.py}"
N2_LAUNCH="${N2_LAUNCH:-ros2 launch yahboomcar_nav display_nav_launch.py}"
N3_LAUNCH="${N3_LAUNCH:-ros2 launch yahboomcar_nav navigation_dwa_launch.py}"

find_container() {
  if [ -n "${NAV_DOCKER_CID:-}" ]; then
    docker ps -a --format '{{.ID}}' | grep "^${NAV_DOCKER_CID}" | head -1
    return
  fi
  local line cid img
  while IFS= read -r line; do
    cid="${line%% *}"
    img="${line#* }"
    case "$img" in
      *autodrive*|*icar*|*ros-foxy*|*ros-humble*|*yahboom*)
        echo "$cid"
        return
        ;;
    esac
  done < <(docker ps -a --format '{{.ID}} {{.Image}}')
  docker ps -a --format '{{.ID}}' | head -1
}

resolve_nav_cmd() {
  local alias_name="$1"
  local launch_cmd="$2"
  # 容器内测试别名是否存在
  if docker exec "$CID" bash -lc "type ${alias_name}" &>/dev/null; then
    echo "${alias_name}"
  else
    echo "${launch_cmd}"
  fi
}

CID="$(find_container || true)"
if [ -z "$CID" ]; then
  echo "[nav] 错误: 未找到 Docker 容器。请先运行 run_docker_autodrive.sh 或设置 NAV_DOCKER_CID"
  exit 1
fi

echo "[nav] 使用容器 ID: ${CID:0:12} (完整: $CID)"

if docker ps --format '{{.ID}}' | grep -q "^${CID}"; then
  echo "[nav] 容器已在运行"
else
  echo "[nav] 启动容器 (docker start)..."
  docker start "$CID"
  sleep 2
fi

N1_CMD="$(resolve_nav_cmd n1 "$N1_LAUNCH")"
N2_CMD="$(resolve_nav_cmd n2 "$N2_LAUNCH")"
N3_CMD="$(resolve_nav_cmd n3 "$N3_LAUNCH")"

launch_tmux_window() {
  local name="$1"
  local inner="$2"
  if ! tmux has-session -t rosmaster_nav 2>/dev/null; then
    tmux new-session -d -s rosmaster_nav -n "$name" \
      "docker exec -it $CID bash -lic '$inner'"
  else
    tmux new-window -t rosmaster_nav -n "$name" \
      "docker exec -it $CID bash -lic '$inner'"
  fi
}

launch_gnome() {
  local title="$1"
  local inner="$2"
  gnome-terminal --title="$title" -- bash -c \
    "echo '=== ${title} ==='; docker exec -it ${CID} bash -lic $(printf '%q' "$inner"); exec bash"
}

launch_xfce() {
  local title="$1"
  local inner="$2"
  xfce4-terminal --title="$title" -e bash -c \
    "echo '=== ${title} ==='; docker exec -it ${CID} bash -lic $(printf '%q' "$inner"); exec bash"
}

open_n1() {
  echo "[nav] 打开终端 n1: $N1_CMD"
  if [ "$USE_TMUX" = true ]; then
    launch_tmux_window n1 "$N1_CMD"
  elif command -v gnome-terminal &>/dev/null; then
    launch_gnome "nav-n1" "$N1_CMD"
  elif command -v xfce4-terminal &>/dev/null; then
    launch_xfce "nav-n1" "$N1_CMD"
  else
    echo "[nav] 无 gnome-terminal/tmux，请手动开终端执行:"
    echo "  docker exec -it $CID bash -lic '$N1_CMD'"
    return 1
  fi
}

open_n2() {
  echo "[nav] 打开终端 n2 (RViz): $N2_CMD"
  if [ "$USE_TMUX" = true ]; then
    launch_tmux_window n2 "$N2_CMD"
  elif command -v gnome-terminal &>/dev/null; then
    launch_gnome "nav-n2" "$N2_CMD"
  elif command -v xfce4-terminal &>/dev/null; then
    launch_xfce "nav-n2" "$N2_CMD"
  else
    echo "  docker exec -it $CID bash -lic '$N2_CMD'"
  fi
}

open_n3() {
  echo "[nav] 打开终端 n3 (DWA): $N3_CMD"
  if [ "$USE_TMUX" = true ]; then
    launch_tmux_window n3 "$N3_CMD"
  elif command -v gnome-terminal &>/dev/null; then
    launch_gnome "nav-n3" "$N3_CMD"
  elif command -v xfce4-terminal &>/dev/null; then
    launch_xfce "nav-n3" "$N3_CMD"
  else
    echo "  docker exec -it $CID bash -lic '$N3_CMD'"
  fi
}

open_n1

if [ "$WAIT_STAGGER" = true ]; then
  echo "[nav] 等待 ${N1_DELAY}s 让 n1 起来..."
  sleep "$N1_DELAY"
  open_n2
  echo "[nav] 等待 ${N2_DELAY}s 后启动 n3..."
  sleep "$N2_DELAY"
  open_n3
else
  open_n2
  open_n3
fi

echo ""
echo "=========================================="
echo "  Docker 导航已拉起"
echo "  容器: ${CID:0:12}"
echo "  n1: $N1_CMD"
echo "  n2: $N2_CMD"
echo "  n3: $N3_CMD"
echo "------------------------------------------"
echo "  RViz: 2D Pose Estimate → 2D Goal Pose"
echo "  巡检: cd ~/Rosmaster-App/rosmaster && bash start_patrol_host.sh --bg"
if [ "$USE_TMUX" = true ]; then
  echo "  tmux 附着: tmux attach -t rosmaster_nav"
fi
echo "=========================================="
