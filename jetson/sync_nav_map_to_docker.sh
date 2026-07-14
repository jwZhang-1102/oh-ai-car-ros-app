#!/bin/bash
# 将宿主机最新地图同步到 Docker 导航使用的 install/maps（n3 默认读 yahboomcar.yaml）
#
# 用法（Jetson 宿主机）:
#   bash sync_nav_map_to_docker.sh
#   bash sync_nav_map_to_docker.sh --dry-run
#
# 同步后需重启 n1/n2/n3，并在 RViz 重新 2D Pose Estimate。
set -euo pipefail

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *)
      echo "未知参数: $arg （可用 --dry-run）"
      exit 1
      ;;
  esac
done

HOST_MAP_DIR="${HOST_MAP_DIR:-/home/jetson/code/yahboomcar_ws/src/yahboomcar_nav/maps}"
HOST_PGM="${HOST_MAP_DIR}/yahboomcar.pgm"
HOST_YAML="${HOST_MAP_DIR}/yahboomcar.yaml"

CONTAINER_MAP_DIR="/root/yahboomcar_ros2_ws/yahboomcar_ws/install/yahboomcar_nav/share/yahboomcar_nav/maps"
CONTAINER_PGM="${CONTAINER_MAP_DIR}/yahboomcar.pgm"
CONTAINER_YAML="${CONTAINER_MAP_DIR}/yahboomcar.yaml"

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

if [ ! -f "$HOST_PGM" ] || [ ! -f "$HOST_YAML" ]; then
  echo "[sync_map] 错误: 宿主机地图不存在"
  echo "  需要: $HOST_PGM"
  echo "        $HOST_YAML"
  exit 1
fi

CID="$(find_container || true)"
if [ -z "$CID" ]; then
  echo "[sync_map] 错误: 未找到 Docker 容器，请先 docker ps -a 或设置 NAV_DOCKER_CID"
  exit 1
fi

echo "[sync_map] 容器: ${CID:0:12}"
echo "[sync_map] 源（宿主机）:"
ls -lh "$HOST_PGM" "$HOST_YAML"
echo "[sync_map] 目标（容器 install）: $CONTAINER_MAP_DIR"

if [ "$DRY_RUN" = true ]; then
  echo "[sync_map] --dry-run 未执行复制"
  exit 0
fi

echo "[sync_map] 备份容器内当前默认地图..."
docker exec "$CID" bash -lc "
  set -e
  cd '$CONTAINER_MAP_DIR'
  ts=\$(date +%Y%m%d_%H%M%S)
  cp -a yahboomcar.pgm yahboomcar.pgm.bak.\$ts 2>/dev/null || true
  cp -a yahboomcar.yaml yahboomcar.yaml.bak.\$ts 2>/dev/null || true
"

echo "[sync_map] 复制宿主机 7月7日地图 → 容器..."
docker cp "$HOST_PGM" "${CID}:${CONTAINER_PGM}"
docker cp "$HOST_YAML" "${CID}:${CONTAINER_YAML}"

echo "[sync_map] 容器内结果:"
docker exec "$CID" ls -lh "$CONTAINER_PGM" "$CONTAINER_YAML"
docker exec "$CID" head -5 "$CONTAINER_YAML"

echo ""
echo "[sync_map] 完成。下一步:"
echo "  1) 停掉 n1/n2/n3（若在跑）"
echo "  2) n1 → n3 → n2"
echo "  3) RViz: 2D Pose Estimate → 2D Goal Pose"
echo "  4) 验证: docker exec -it $CID bash -lc 'ros2 param get /map_server yaml_filename'  （需 n3 在跑）"
