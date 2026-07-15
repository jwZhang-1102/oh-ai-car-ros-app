# 智检哨兵 · Jetson 巡检脚本（patrol）

本目录脚本部署到小车宿主机 `~/Rosmaster-App/rosmaster/` 后使用，实现 **YOLO 异物检测、事件留痕、HTTP 6700、音乐伴舞**，并与 Docker 导航并行（边走边检）。

交付范围与终期答辩 PPT 一致。日常步骤见 [智能小车操作手册.md](../../智能小车操作手册.md)；目录总览见 [../README.md](../README.md)。

---

## 核心组件

| 文件 | 作用 |
|------|------|
| `patrol_detector.py` | 摄像头取帧 → YOLOv5 推理 → 连续帧确认 → 截图 + `events.jsonl`；触发蜂鸣/语音等告警逻辑 |
| `patrol_server.py` | Flask HTTP **6700**：`/health`、`/events`、`/snapshot/<文件>` |
| `start_patrol_host.sh` | 一键启检测 + 6700；推荐 `--bg` |
| `stop_patrol_host.sh` | 停止巡检相关进程 |
| `music.py` | 音乐伴舞（独占串口；须停导航与 `ros/run`） |
| `rosmaster_buzzer.py` | 蜂鸣相关辅助（告警用；注意与导航的串口策略） |

前台检测时不要与占用摄像头的 `ros/run` 视频同时开；`--bg` 巡检默认可与 Docker 导航并行（不占底盘串口）。

---

## 快速开始（推荐答辩路径）

```bash
cd ~/Rosmaster-App/rosmaster

# 后台巡检：检测瓶子弹告警 + 6700（与导航并行）
bash start_patrol_host.sh --bg
curl -sf http://127.0.0.1:6700/health

# 另按操作手册启动导航：s → d+n1 / d+n2 / d+n3，RViz 设点
# 手机 App → 巡检模式 → 智能巡检页

# 停止
bash stop_patrol_host.sh
```

常用参数：

| 参数 | 说明 |
|------|------|
| `--bg` | 后台运行（推荐）；无检测弹窗，降载推理 |
| `--display` | 弹出检测窗口（更吃算力，导航可能变卡） |
| `--nav-lite` | 更轻量推理，导航仍卡顿时尝试 |
| `--no-stop-nav` | 检出后尽量不影响停车策略（按脚本实际行为） |
| `--buzzer-serial` | 串口蜂鸣机模式：**勿与 Docker n1 并行** |

验证事件：

```text
http://<小车IP>:6700/events
http://<小车IP>:6700/snapshot/<截图文件名>
```

---

## 分模块说明

### 1. 仅跑检测写事件

```bash
cd ~/Rosmaster-App/rosmaster
python3 patrol_detector.py
```

输出示例：

- `events.jsonl` — 每行一条事件 JSON  
- `capture/patrol/*.jpg` — 告警截图  

### 2. 仅跑 HTTP（已有事件文件时）

```bash
pip3 install flask --user   # 若未安装
python3 patrol_server.py
```

一般由 `start_patrol_host.sh` 一并拉起，无需单独开。

### 3. 音乐伴舞

```bash
# 先停止 Docker 导航与 ros/run
amixer -c 0 set PCM 90% unmute
python3 music.py
```

音频与底盘动作开场同步；结束后停车归零。与导航/遥控**互斥**。

---

## 与 App / 导航的配合

| 场景 | 本目录 | App | 导航 |
|------|--------|-----|------|
| 边走边检 | `--bg` 巡检 | 巡检模式（6700） | `n1`+`n3` 等 |
| 手机遥控 | 先 `stop_patrol_host`（若要视频） | TCP+视频 | 必须先停容器再 `ros/run` |
| 伴舞 | `music.py` | 不控车 | 停掉 |

端口：**6700** 巡检；控车 **6000** / 视频 **6500** 由 `ros/run` 等提供，见仓库根文档。

---

## 部署

```cmd
cd /d D:\oh-ai-car-ros-app
scp jetson/patrol/patrol_detector.py jetson/patrol/patrol_server.py jetson/patrol/start_patrol_host.sh jetson/patrol/stop_patrol_host.sh jetson/patrol/music.py jetson@<IP>:~/Rosmaster-App/rosmaster/
```

```bash
sed -i 's/\r$//' start_patrol_host.sh stop_patrol_host.sh
```

---

## 说明：非交付内容

仓库中若仍存在 `MISSION.md`、`nav_mission_coordinator.py`、`danger_zones*`、激光危险区脚本等，属于早期实验或备选代码，**不是**终期 PPT 交付功能。演示与说明书请勿将其作为主路径；联调以操作手册 + `start_patrol_host.sh --bg` + Docker 导航为准。

更细的并行说明、历史联调记录可参考同目录其他 md（内容若与 PPT 冲突，以 PPT / 操作手册为准）。
