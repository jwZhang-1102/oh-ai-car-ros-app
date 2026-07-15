# 智检哨兵：自主巡防与多模式人机协同

基于 **OpenHarmony / ArkTS** 的 Rosmaster 小车遥控应用，并在 Jetson 上扩展视觉巡检与人机协同能力。

**能力范围以终期答辩 PPT 为准**：自主导航、YOLO 异物巡检（边走边检）、多级告警与事件留痕、鸿蒙 App（控车/视频/巡检）、罗技 G29、手势控车、音乐伴舞，以及模式切换与资源互斥说明。  
**不包含**危险区域检测、mission 任务编排等未在 PPT 中交付的功能。

需要人工控车时采用**模式切换**（停 Docker 导航 → `ros/run` → App / G29），不是导航过程中的无缝热接管。

| 项 | 说明 |
|------|------|
| 包名 | `com.hoperun.cmartcar` |
| 目标平台 | OpenHarmony API 12（`runtimeOS: "OpenHarmony"`） |
| 默认小车 IP | `10.147.13.194`（可在 App 中修改） |
| Jetson 工程目录 | `~/Rosmaster-App/rosmaster/` |
| 团队 | 实训小组2（张经纬、曹棪、郑浩然、王才睿、李昕哲） |

**相关文档**

| 文档 | 内容 |
|------|------|
| [智能小车操作手册.md](./智能小车操作手册.md) | 演示与验收操作（推荐先看） |
| [智能小车使用手册.md](./智能小车使用手册.md) | 亚博原厂 Docker / 建图 / 导航 |
| [doc/ros_api.md](./doc/ros_api.md) | TCP 控车协议 |
| [App/README.md](./App/README.md) | 鸿蒙 App 使用与工程总览 |
| [entry/README.md](./entry/README.md) | App 主模块（entry）源码说明 |
| [jetson/README.md](./jetson/README.md) | Jetson 脚本目录总览 |
| [jetson/patrol/README.md](./jetson/patrol/README.md) | 巡检 / 告警 / 伴舞脚本 |
| [tools/README.md](./tools/README.md) | 罗技 G29 控车参数 |
| `用户手册.docx` / `项目开发文档.docx` / `项目测试文档.docx` / `需求分析报告.docx` | 提交用文档 |

---

## 功能概览

### OpenHarmony App

| 功能 | 说明 |
|------|------|
| 网络配置 | IP、TCP 6000 / 视频 6500 / 巡检 6700；支持巡检模式、遥控+视频等组合 |
| 遥控 / 麦轮 | 摇杆（cmd 10）+ 方向键（cmd 15）+ 麦克纳姆四轮（cmd 21） |
| 实时视频 | HTTP MJPEG（6500），驾驶/全景页拉取 |
| 智能巡检 | HTTP 6700：事件列表、截图、约 4s 自动刷新、置信度分级 |
| 偏好存储 | Preferences 持久化 IP 与端口 |

当前为**单车连接**：`TCPClientManager` 维护一条 TCP；控车经 `CarApi` 发送。

### Jetson 端

| 功能 | 说明 |
|------|------|
| 自主导航 | Docker 内 n1 / n2 / n3（Nav2），RViz 设 Pose / Goal |
| YOLO 巡检 | `patrol_detector.py`：检出瓶子等，连续帧确认后告警 |
| 事件服务 | `patrol_server.py`：6700 提供 `/health`、`/events`、`/snapshot` |
| 告警 | 车体蜂鸣 + USB 语音；截图写入 `events.jsonl` |
| 一键启停 | `start_patrol_host.sh --bg` / `stop_patrol_host.sh` |
| 手势控车 | 容器内 MediaPipe → `/cmd_vel`（需 n1） |
| 音乐伴舞 | 宿主机 `music.py`：播歌 + 底盘编排动作（独占串口） |

### PC 端

| 功能 | 说明 |
|------|------|
| 罗技 G29 | `tools/logitech_g29_drive.py`：踏板/方向盘 → TCP 6000（与 App 同协议） |

---

## 网络端口

| 端口 | 协议 | 用途 |
|------|------|------|
| **6000** | TCP | App / G29 控车（需 `ros/run`） |
| **6500** | HTTP | 默认视频（`/index2`、`/video_feed`） |
| **6501** | HTTP | 可选低延迟视频（需单独启动） |
| **6700** | HTTP | 巡检（`/health`、`/events`、`/snapshot/...`） |

手机、PC 与小车须同一局域网。浏览器地址**必须带端口**。

```bash
# Jetson 自检
ss -tlnp | grep -E '6000|6500|6501|6700'
curl -sf http://127.0.0.1:6700/health
```

---

## 资源互斥（必读）

| 不要同时开启 | 原因 |
|--------------|------|
| `ros/run` 与 Docker 导航（n1） | 争用底盘串口 |
| 6500 视频与 YOLO 巡检 | 争用 USB 摄像头 |
| `music.py` 与 `ros/run` / 导航 | 争用串口 |
| App 与 G29 同时控车 | 共用 TCP 6000 |

| 推荐组合 | 说明 |
|----------|------|
| n1/n2/n3 + 巡检 `--bg` | 主演示：边走边检；App 用巡检模式看 6700 |
| 停导航 + `ros/run` + App 或 G29 | 人工遥控 |
| 单独跑 `music.py` | 伴舞展示 |

---

## 架构

```
┌──────────────────────────────────────────────────────────────┐
│  OpenHarmony App                                              │
│  ├─ TCP :6000   遥控 / 麦轮 / 驾驶                             │
│  ├─ HTTP :6500  视频直播                                       │
│  └─ HTTP :6700  巡检事件 / 截图                                │
└────────────────────────────┬─────────────────────────────────┘
                             │ 局域网
         ┌───────────────────┼───────────────────┐
         │                   │                   │
┌────────▼────────┐  ┌───────▼────────┐  ┌───────▼────────┐
│ PC G29 脚本      │  │ Jetson 宿主机   │  │ Docker 导航     │
│ → TCP 6000      │  │ 巡检 --bg:6700  │  │ n1 底盘/雷达    │
│                 │  │ ros/run:6000   │  │ n2 RViz         │
│                 │  │ music.py       │  │ n3 DWA 导航     │
│                 │  │ （与 Docker    │  │ 可选手势节点    │
│                 │  │  串口互斥）    │  │                 │
└─────────────────┘  └────────────────┘  └─────────────────┘
```

---

## 推荐演示流程

### ① 自主巡防（主场景）

```bash
cd ~/Rosmaster-App/rosmaster
# 地图有更新时：bash sync_nav_map_to_docker.sh

bash start_patrol_host.sh --bg
curl -sf http://127.0.0.1:6700/health
```

导航（与使用手册一致）：

1. 宿主机：`s` 启动导航容器  
2. 开 3 个终端，分别 `d` 进入容器后执行 `n1`、`n2`、`n3`  
3. RViz：**2D Pose Estimate** → **2D Goal Pose**  
4. App：**保存并进入（巡检模式）** → 智能巡检，查看告警  

停止：导航终端 `Ctrl+C` 后 `exit`；宿主机 `t`；`bash stop_patrol_host.sh`。

### ② 人工遥控（模式切换）

```bash
t                              # 停导航容器
bash stop_patrol_host.sh       # 需要 6500 视频时释放摄像头
ros/run                        # 提供 6000（及默认视频）
```

- **鸿蒙 App**：勾选 TCP + 视频 → 遥控 / 麦轮 / 全景  
- **G29（Windows）**：

```cmd
cd D:\oh-ai-car-ros-app\tools
python logitech_g29_drive.py --backend pygame --mode pedal --ip 10.147.13.194
```

读不到轴时可改 `--backend winmm`。详见 [tools/README.md](./tools/README.md)。

### ③ 手势控车（可选）

```bash
s
# 终端 A：d → n1
# 终端 B：d → python3 /root/gesture_control_ros2.py
```

建议先取消导航 Goal，避免与手势争用 `/cmd_vel`。

### ④ 音乐伴舞（可选）

```bash
# 先停导航与 ros/run
amixer -c 0 set PCM 90% unmute
python3 music.py
```

---

## 开发环境（App）

推荐 **DevEco Studio** + **OpenHarmony SDK API 12**。

1. 根目录 `local.properties`（已 gitignore）：`sdk.dir`、`nodejs.dir`  
2. `build-profile.json5`：`compileSdkVersion` / `targetSdkVersion` = `12`  
3. USB 连真机，Module 选 `entry`；网络页填 IP 后进入对应模式  

### App 常见问题

| 现象 | 处理 |
|------|------|
| 无法控车 | 确认已停导航且 `ros/run` 使 6000 在听；IP/同网正确 |
| 视频黑屏 | 确认 6500；与巡检勿同时占摄像头 |
| 巡检无事件 | `curl ...:6700/health`；确认已 `start_patrol_host.sh` |
| 构建 `EPERM` | 关多余 IDE，删 `.hvigor` 重编 |

---

## Jetson 脚本说明

工作目录：`~/Rosmaster-App/rosmaster/`（可将本仓库 `jetson/patrol/` 等同步上去）。

| 文件 / 指令 | 作用 |
|-------------|------|
| `s` / `t` / `d` | 启动 / 停止 / 进入导航容器（环境快捷指令） |
| `n1` / `n2` / `n3` | 导航基础 / RViz / DWA（容器内） |
| `start_patrol_host.sh --bg` | 后台巡检（检测 + 6700，默认不占串口） |
| `stop_patrol_host.sh` | 停止巡检 |
| `patrol_detector.py` | YOLO 检测、截图、事件 |
| `patrol_server.py` | HTTP 6700 |
| `music.py` | 音乐伴舞 |
| `start_low_latency_video.sh` | 可选 6501 低延迟视频 |
| `sync_nav_map_to_docker.sh` | 地图同步到导航容器 |

Windows 上传示例（按需增减文件）：

```cmd
cd /d D:\oh-ai-car-ros-app
scp jetson/patrol/patrol_detector.py jetson/patrol/patrol_server.py jetson/patrol/start_patrol_host.sh jetson/patrol/stop_patrol_host.sh jetson/patrol/music.py jetson@10.147.13.194:~/Rosmaster-App/rosmaster/
```

若 shell 报 `$'\r'`：`sed -i 's/\r$//' *.sh`

---

## 仓库结构

```
oh-ai-car-ros-app
├─ doc/
│  ├─ prototype/           # App 界面原型
│  └─ ros_api.md           # TCP 6000 协议
├─ jetson/
│  ├─ patrol/              # 巡检、告警、伴舞等
│  └─ low_latency_mjpeg.py # 低延迟视频相关
├─ entry/src/main/ets/     # App 主模块（控车、视频、巡检页）
├─ Rocker/                 # 摇杆 HAR
├─ tools/                  # G29 等 PC 工具
├─ 智能小车操作手册.md
├─ 智能小车使用手册.md
├─ 用户手册.docx 等提交文档
└─ readme.md
```

---

## API 索引

| 类型 | 地址 / 文档 |
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

## 后续规划（展望，未交付）

终期 PPT「总结与展望」中提及的增强方向，**当前版本未实现**，仅作展望：

- 告警在 App 地图上标点（异物发现位置可视化）
- 按类别配置告警策略（如 bottle 语音、person 仅记录）
- 航点巡航 + 巡检报告自动生成
- 激光雷达距离与视觉联合，提升复杂场景可靠性

---

## 参考

- 操作与验收：[智能小车操作手册.md](./智能小车操作手册.md)
- 亚博原厂流程：[智能小车使用手册.md](./智能小车使用手册.md)
- 巡检细节：[jetson/patrol/README.md](./jetson/patrol/README.md)
- G29：[tools/README.md](./tools/README.md)
