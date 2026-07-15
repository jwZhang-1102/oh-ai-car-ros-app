# jetson 目录说明

本目录存放需部署到 **Jetson / 小车宿主机**（工作目录通常为 `~/Rosmaster-App/rosmaster/`）的脚本与巡检相关代码，配合仓库内 OpenHarmony App 与 PC 端 G29 工具完成「智检哨兵」演示。

**交付能力以终期答辩 PPT 为准**：导航并行巡检、YOLO 告警留痕、宿主机 HTTP 6700、音乐伴舞、低延迟视频辅助等。  
**不作为项目交付能力**：危险区域检测、mission 任务编排（仓库若残留相关脚本，仅作实验遗留，演示与文档请勿作为主路径）。

日常操作请优先看：[智能小车操作手册.md](../智能小车操作手册.md)。

---

## 目录结构

```
jetson/
├─ README.md                      # 本文件
├─ sync_nav_map_to_docker.sh      # 地图同步到导航 Docker
├─ start_nav_docker.sh            # 历史/备选：一键开导航三终端（验收主路径用手册 s/d/n1–n3）
├─ start_low_latency_video.sh     # 可选：6501 低延迟 MJPEG
├─ low_latency_mjpeg.py           # 低延迟视频服务实现
└─ patrol/                        # 巡检、告警、伴舞等（见该目录 README）
   ├─ start_patrol_host.sh / stop_patrol_host.sh
   ├─ patrol_detector.py / patrol_server.py
   ├─ music.py
   └─ …
```

---

## 与答辩功能的对应关系

| PPT / 演示能力 | 本目录相关入口 |
|----------------|----------------|
| 自主导航（Docker n1/n2/n3） | 平台快捷指令 `s`/`t`/`d` + 容器内 `n1`/`n2`/`n3`；地图更新可用 `sync_nav_map_to_docker.sh` |
| YOLO 异物巡检 + 告警 | `patrol/start_patrol_host.sh --bg` → detector + 6700 |
| App 拉取事件 | `patrol/patrol_server.py`（HTTP **6700**） |
| 模式切换后遥控 | 停导航后宿主机 `ros/run`（工程原有，不在本目录内实现） |
| 音乐伴舞 | `patrol/music.py`（独占串口，须停导航与 `ros/run`） |
| G29 辅视（可选） | `start_low_latency_video.sh` → **6501**（先释放摄像头） |
| 手势控车 | 容器内 `gesture_control_ros2.py`（镜像内脚本，非本目录） |

---

## 推荐主场景（导航 + 巡检并行）

在小车宿主机：

```bash
cd ~/Rosmaster-App/rosmaster

# 地图有更新时
bash sync_nav_map_to_docker.sh   # 若脚本已拷到该目录

# 1) 巡检后台（不占底盘串口，默认可与 Docker 导航并行）
bash start_patrol_host.sh --bg
curl -sf http://127.0.0.1:6700/health

# 2) 导航：s 启动容器 → 三终端 d 后分别 n1、n2、n3
# 3) RViz：2D Pose Estimate → 2D Goal Pose
# 4) 手机 App「巡检模式」查看告警
```

停止巡检：`bash stop_patrol_host.sh`。导航结束：节点 `Ctrl+C`，宿主机 `t`。

---

## 端口

| 端口 | 说明 |
|------|------|
| 6000 | TCP 控车（`ros/run`，App / G29） |
| 6500 | 默认视频 |
| 6501 | 可选低延迟视频（本目录脚本） |
| 6700 | 巡检 HTTP（本目录 `patrol_server`） |

互斥规则见仓库根 [readme.md](../readme.md) 与操作手册。

---

## 部署提示

从 Windows 同步巡检相关文件示例：

```cmd
cd /d D:\oh-ai-car-ros-app
scp jetson/patrol/patrol_detector.py jetson/patrol/patrol_server.py jetson/patrol/start_patrol_host.sh jetson/patrol/stop_patrol_host.sh jetson/patrol/music.py jetson@10.147.13.194:~/Rosmaster-App/rosmaster/
scp jetson/sync_nav_map_to_docker.sh jetson/start_low_latency_video.sh jetson/low_latency_mjpeg.py jetson@10.147.13.194:~/Rosmaster-App/rosmaster/
```

上传 shell 后若报 `$'\r'`：

```bash
sed -i 's/\r$//' *.sh
```

---

## 子文档

- 巡检与伴舞细节：[patrol/README.md](./patrol/README.md)
- App 模块：[entry/README.md](../entry/README.md)
- G29：[tools/README.md](../tools/README.md)
- 仓库总览：[readme.md](../readme.md)
