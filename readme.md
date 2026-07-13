# 智慧小车 App + 智检哨兵（OpenHarmony + Jetson）

基于 OpenHarmony / ArkTS 的 Rosmaster 小车遥控应用，并扩展 **「智检哨兵」** 视觉巡检能力：YOLO 检测、事件留痕、App 拉取告警，可选 **地图危险区 + 蜂鸣器联动**。

- **包名**：`com.hoperun.cmartcar`
- **目标平台**：OpenHarmony API 12（`runtimeOS: "OpenHarmony"`）
- **App 控车协议**：[doc/ros_api.md](./doc/ros_api.md)
- **Jetson 巡检脚本**：[jetson/patrol/README.md](./jetson/patrol/README.md)
- **导航 + 巡检联调**：[jetson/patrol/INTEGRATION.md](./jetson/patrol/INTEGRATION.md)

---

## 功能概览

### App 端

| 功能 | 说明 |
|------|------|
| 网络配置 | 小车 IP、TCP / 视频 / 巡检端口；支持「仅巡检」「仅遥控」等组合 |
| 遥控驾驶 | 摇杆 + 方向按钮（cmd 10 / 15） |
| 麦克纳姆轮 | 四轮独立速度（cmd 21） |
| 实时视频 | HTTP MJPEG（6500），`MjpegFramePoller` 拉帧显示 |
| **智能巡检** | HTTP 6700 拉事件列表、查看截图、自动刷新 |
| 偏好存储 | IP 与各端口通过 Preferences 持久化 |

当前为**单车连接**：`TCPClientManager` 单例维护一条 TCP 连接，控车指令经 `CarApi` 发送。

### Jetson 端（智检哨兵）

| 功能 | 说明 |
|------|------|
| YOLO 检测 | `patrol_detector.py`：person / bottle 等，连续帧触发告警 |
| 事件 HTTP | `patrol_server.py`：6700 提供 `/events`、`/snapshot`、`/health` |
| 危险区联动 | `danger_zones.json` + map 位姿 + person → 蜂鸣（`[DANGER]`） |
| **激光危险区** | `danger_zone_lidar.py`：人在危险区（`/scan` + map，无 YOLO） |
| 一键启停 | `start_patrol_host.sh` / `stop_patrol_host.sh` |
| 自检 | `verify_danger_link.sh`：多边形、位姿、蜂鸣器 |

---

## 网络与端口

| 项目 | 默认端口 | 说明 |
|------|----------|------|
| 小车 IP | `10.147.13.194` | 网络配置页可改 |
| TCP 控车 | **6000** | `$...#` 帧，需 `ros/run` |
| 视频直播 | **6500** | `/index2`、`/video_feed` |
| **巡检 HTTP** | **6700** | `/events`、`/snapshot/<文件名>` |

**重要**：6500 视频与 YOLO 巡检**共用 USB 摄像头**，同一时刻建议**只开一种**（App 网络页已提示）。

```bash
# Jetson 检查端口
ss -tlnp | grep -E '6000|6500|6700'
curl -sf http://127.0.0.1:6700/health
curl -sf http://127.0.0.1:6500/index2 -I
```

---

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│  OpenHarmony App                                             │
│  ├─ TCP :6000  → 遥控 / 麦轮（CarApi + CarEncode）            │
│  ├─ HTTP :6500 → 视频（VideoComponents / MjpegFramePoller）  │
│  └─ HTTP :6700 → 巡检（PatrolPage + PatrolApi）               │
└───────────────────────────┬─────────────────────────────────┘
                            │ 局域网
┌───────────────────────────▼─────────────────────────────────┐
│  Jetson  ~/Rosmaster-App/rosmaster/                          │
│  ├─ ros/run、camera_server     → 6000 / 6500（遥控模式）       │
│  ├─ patrol_server + detector   → 6700 + YOLO（巡检模式）       │
│  └─ Docker n1/n3（可选）       → /amcl_pose（危险区联动）      │
└─────────────────────────────────────────────────────────────┘
```

---

## 使用场景

### 场景 A：App 遥控 + 看视频

1. Jetson：`ros/run`（6000）+ 摄像头服务（6500）
2. App：勾选 **TCP + 视频**，保存并进入
3. 进入遥控 / 麦轮页

### 场景 B：App 智能巡检（答辩常用）

1. Jetson：

   ```bash
   cd ~/Rosmaster-App/rosmaster
   bash start_patrol_host.sh          # 无窗口
   bash start_patrol_host.sh --display # 接显示器时可看检测窗口
   ```

2. App：**保存并进入（巡检模式）** → **智能巡检** → 开启自动刷新
3. 验证：`curl http://<小车IP>:6700/events`

### 场景 C：自主导航 + 巡检 + 危险区

1. Jetson 一键导航（开 3 个终端 n1/n2/n3）：

   ```bash
   cd ~/Rosmaster-App/rosmaster
   bash start_nav_docker.sh
   ```

2. RViz：**2D Pose Estimate** → **2D Goal Pose**
3. 宿主机：`bash start_patrol_host.sh --bg`
4. 车进危险区 + 检出 person → `[DANGER]`

详见 [jetson/patrol/INTEGRATION.md](./jetson/patrol/INTEGRATION.md)。

### 场景 D：PC 罗技 G29 方向盘控车

1. Jetson：`ros/run`（6000）
2. Windows PC：G29 接 USB，`pip install pygame`
3. 运行：[tools/logitech_g29_drive.py](./tools/logitech_g29_drive.py)（详见 [tools/README.md](./tools/README.md)）

```cmd
cd D:\oh-ai-car-ros-app\tools
python logitech_g29_drive.py --ip 10.147.13.194 --max-speed 30
```

---

## 开发环境（App）

推荐 **DevEco Studio 6.1** + **OpenHarmony SDK API 12**。

### 本地配置

1. 根目录 `local.properties`（已 gitignore）：

   ```properties
   sdk.dir=D:/OpenHarmonySDK
   nodejs.dir=C:/path/to/nodejs
   ```

2. `build-profile.json5`：`compileSdkVersion` / `targetSdkVersion` = `12`，`runtimeOS: "OpenHarmony"`
3. `hvigor/hvigor-config.json5`：`daemon: false`（避免 Windows 下 EPERM）

### 运行与调试

1. USB 连接 OpenHarmony 真机，Module 选 `entry`
2. 网络配置页填写 IP，按需勾选 TCP / 视频 / 巡检
3. 横屏运行（`module.json5` → `orientation: landscape`）

### App 常见问题

| 现象 | 处理 |
|------|------|
| 视频黑屏 | 确认 6500 已启；与巡检不要同时占摄像头；查 IP/同网 |
| 巡检无事件 | `curl .../6700/health`；Jetson 上 `bash start_patrol_host.sh` |
| `EPERM` 构建失败 | 关多余 IDE 进程，删 `.hvigor` 重编 |
| `00401008` | 运行配置 Module = `entry` |

---

## Jetson 脚本部署

从 Windows 上传到小车（**cmd 单行**）：

```cmd
cd /d D:\oh-ai-car-ros-app
scp jetson/start_nav_docker.sh jetson/patrol/patrol_detector.py jetson/patrol/patrol_server.py jetson/patrol/start_patrol_host.sh jetson/patrol/stop_patrol_host.sh jetson/patrol/danger_zones.json jetson/patrol/danger_zone_utils.py jetson/patrol/pose_reader.py jetson/patrol/rosmaster_buzzer.py jetson/patrol/verify_danger_link.sh jetson@10.147.13.194:~/Rosmaster-App/rosmaster/
```

Jetson 工作目录：`~/Rosmaster-App/rosmaster/`

| 文件 | 作用 |
|------|------|
| `start_nav_docker.sh` | 一键 docker start + 三终端 n1/n2/n3 |
| `start_patrol_host.sh` | 启动 6700 + YOLO（`--display` / `--bg`） |
| `stop_patrol_host.sh` | 停止巡检进程 |
| `patrol_detector.py` | YOLO 检测、截图、`events.jsonl`、危险区蜂鸣 |
| `patrol_server.py` | Flask HTTP 6700 |
| `danger_zones.json` | RViz 标定的危险多边形 |
| `verify_danger_link.sh` | 位姿 / 多边形 / 蜂鸣自检 |

上传 shell 脚本后若报 `$'\r'` 错误：

```bash
sed -i 's/\r$//' start_nav_docker.sh start_patrol_host.sh verify_danger_link.sh
```

---

## 文件结构

```
oh-ai-car-ros-app
├─ doc
│  ├─ prototype/              # 界面原型图
│  └─ ros_api.md              # TCP 6000 协议
├─ jetson/patrol/             # 智检哨兵 Jetson 脚本与文档
│  ├─ patrol_detector.py
│  ├─ patrol_server.py
│  ├─ start_patrol_host.sh / stop_patrol_host.sh
│  ├─ danger_zones.json
│  ├─ danger_zone_utils.py / pose_reader.py / rosmaster_buzzer.py
│  ├─ verify_danger_link.sh
│  ├─ README.md
│  └─ INTEGRATION.md
├─ entry/src/main/ets
│  ├─ CarUtill/               # 控车编码、CarApi
│  ├─ components/             # 摇杆、视频、按钮
│  ├─ pages/                  # NetworkSettings、Index、RemoteControl、PatrolPage…
│  ├─ patrol/                 # PatrolApi、PatrolEventModel
│  ├─ tcp/                    # TCPClientManager
│  └─ utils/                  # Preferences、MjpegFramePoller、VideoConfig
├─ Rocker/                    # Canvas 摇杆子模块
├─ tools/                     # PC 端工具（G29 方向盘控车等）
│  ├─ logitech_g29_drive.py
│  └─ README.md
├─ 智能小车使用手册.md         # Yahboom 原厂手册（建图、Docker、导航）
└─ readme.md
```

---

## API 索引

| 类型 | 文档 / 地址 |
|------|-------------|
| TCP 控车 | [doc/ros_api.md](./doc/ros_api.md) |
| 视频 | `GET http://{ip}:6500/index2` |
| 巡检健康 | `GET http://{ip}:6700/health` |
| 巡检事件 | `GET http://{ip}:6700/events` |
| 告警截图 | `GET http://{ip}:6700/snapshot/{filename}` |

---

## 项目原型图

### 网络配置（NetworkSettings）

![NetworkSettings.png](./doc/prototype/NetworkSettings.png)

### 主页（Index）

![Index.png](./doc/prototype/Index.png)

### 麦克纳姆轮（MecanumWheel）

![MecanumWheel.png](./doc/prototype/MecanumWheel.png)

### 遥控（RemoteControl）

![RemoteControl1.png](./doc/prototype/RemoteControl1.png)

![RemoteControl2.png](./doc/prototype/RemoteControl2.png)

---

## 后续规划

- **多车同步遥控**：多 TCP 连接 + 广播；视频仍只显示主车
- ~~**PC 罗技方向盘控车**~~ → 已实现，见 [tools/logitech_g29_drive.py](./tools/logitech_g29_drive.py)（G29 + pygame + TCP 6000）
- **巡检地图钉**：事件携带 map 位姿，App 地图展示
- **person 投影到 map**：相机标定 + 距离估算（危险区精确定位）

---

## 参考

- Yahboom 小车实验流程：[智能小车使用手册.md](./智能小车使用手册.md)（3.7 建图导航、3.10 雷达警卫等）
- 巡检脚本细节：[jetson/patrol/README.md](./jetson/patrol/README.md)
