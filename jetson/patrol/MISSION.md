# 自主导航 + 巡检告警停车 + 人工绕障 + 恢复终点

目标流程：

1. RViz 设起点、终点，小车自动导航  
2. YOLO 检出 **bottle** → **暂停 Nav2、停车、蜂鸣、记录事件**  
3. 操作员 **人工绕过** 异物  
4. **恢复导航** 至原终点（`mission_waypoints.json`）

不改 App；通过 Jetson 宿主机 HTTP **6700** 与 `patrol_detector` 联动。

---

## 新增文件

| 文件 | 作用 |
|------|------|
| `nav_mission_coordinator.py` | 任务状态机；docker exec 暂停/恢复 Nav2、`/cmd_vel` teleop |
| `mission_waypoints.json` | 持久化终点坐标（map 系） |
| `mission_state.json` | 运行时状态（自动生成） |
| `start_mission_nav.sh` | 一键启动 mission 模式 |

## 修改文件

| 文件 | 变更 |
|------|------|
| `patrol_server.py` | `/mission/*` HTTP API |
| `patrol_detector.py` | `--pause-nav-on-alert` |
| `start_patrol_host.sh` | `--mission` 开关 |

---

## 部署到小车

```bash
# Windows 开发机
scp jetson/patrol/nav_mission_coordinator.py \
    jetson/patrol/mission_waypoints.json \
    jetson/patrol/patrol_server.py \
    jetson/patrol/patrol_detector.py \
    jetson/patrol/rosmaster_buzzer.py \
    jetson/patrol/start_patrol_host.sh \
    jetson/patrol/start_mission_nav.sh \
    jetson@10.147.13.194:~/Rosmaster-App/rosmaster/

# 小车（上传后若从 Windows 拷贝，先去 CRLF）
cd ~/Rosmaster-App/rosmaster
sed -i 's/\r$//' *.sh
```

---

## 答辩 Demo 步骤

### 1. 启动 Docker 导航

```bash
bash start_nav_docker.sh
# 容器内 n1 → n2(RViz) → n3
# RViz: 2D Pose Estimate
```

### 2. 配置终点

方式 A — 编辑 JSON（与 RViz Goal 坐标一致）：

```bash
nano mission_waypoints.json
# "end": {"x": 1.5, "y": 2.0, "yaw": 0.0}
```

方式 B — HTTP（需 patrol_server 已跑）：

```bash
curl -X POST http://127.0.0.1:6700/mission/set_end \
  -H "Content-Type: application/json" \
  -d '{"x":1.5,"y":2.0,"yaw":0.0}'
```

### 3. 启动任务模式巡检

```bash
bash start_mission_nav.sh
# 或: bash start_patrol_host.sh --mission --bg
```

### 4. RViz 发 Goal

**2D Goal Pose** 设目标点（与 `mission_waypoints.json` 一致），小车开始走。

### 5. 触发告警

路上放 **瓶子** → 日志：

```text
[ALERT] ... class=bottle ... beep=on ...
```

`events.jsonl` 增加字段：`mission_state`, `nav_paused`。

### 6. 人工绕障

**方式 A** — Docker 容器内键盘 teleop（若已装）：

```bash
docker exec -it <cid> bash -lic 'ros2 run teleop_twist_keyboard teleop_twist_keyboard'
```

**方式 B** — HTTP teleop（宿主机，不占 TCP 6000）：

```bash
# 或使用 Windows G29（推荐答辩演示）:
# cd tools && python g29_mission_drive.py --backend winmm --ip <小车IP> --mode pedal

# 前进
curl -X POST http://127.0.0.1:6700/mission/teleop \
  -H "Content-Type: application/json" \
  -d '{"vx":0.15,"vy":0,"wz":0,"duration":0.8}'

# 转向
curl -X POST http://127.0.0.1:6700/mission/teleop \
  -H "Content-Type: application/json" \
  -d '{"vx":0,"vy":0,"wz":0.4,"duration":0.6}'

# 停车
curl -X POST http://127.0.0.1:6700/mission/stop
```

### 7. 恢复自动导航

```bash
curl -X POST http://127.0.0.1:6700/mission/resume
```

协调器会：零速 → 重发 `/goal_pose`（终点）→ `bt_navigator resume`。

### 8. 查看状态

```bash
curl http://127.0.0.1:6700/mission/status | python3 -m json.tool
tail -f events.jsonl
tail -f patrol_detector.log
```

App **智能巡检** 页仍可看事件截图（无需改 App）。

---

## HTTP API 一览

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/mission/status` | 当前任务状态 |
| POST | `/mission/start` | 加载 waypoints，标记 navigating |
| POST | `/mission/set_end` | `{"x","y","yaw?"}` 写终点 |
| POST | `/mission/alert` | detector 内部调用 |
| POST | `/mission/teleop` | `{"vx","vy","wz","duration?"}` 人工速度 |
| POST | `/mission/stop` | 停止 teleop |
| POST | `/mission/resume` | 恢复至终点 |
| POST | `/mission/manual` | 显式进入人工接管状态 |

---

## 状态机

```
idle → navigating → alert_stopped → manual_override
                         ↑                │
                         └── resume ──────┘
                              → navigating → completed
```

---

## 注意事项

| 项 | 说明 |
|----|------|
| 串口 | Docker `n1` 占 `/dev/myserial`，勿开宿主机 `ros/run` |
| TCP 6000 | 人工绕障用 **HTTP teleop → /cmd_vel**，不用 App TCP |
| 摄像头 | 勿开 6500 视频推流，YOLO 占 video0 |
| 蜂鸣 | mission 模式经容器 `/beep` 话题（需 n1）；失败见 `patrol_server.log` 中 `beep=fail` |
| 终点 | **resume 依赖 mission_waypoints.json**，必须与真实 Goal 一致 |
| Nav2 暂停 | 优先 `bt_navigator/pause`；若无该服务则 cancel goal + cmd_vel 零 |

---

## 故障排查

| 现象 | 处理 |
|------|------|
| 检测到异物但不停 | 确认 `--mission` 或 `--pause-nav-on-alert`；`curl /mission/status` |
| resume 后不走 | 检查 `mission_waypoints.json` 坐标；RViz 看 Goal 是否重发 |
| teleop 不动 | 确认处于 `alert_stopped`；`docker exec` 内 `ros2 topic echo /cmd_vel` |
| mission alert 失败 | 先起 `patrol_server`；看 `patrol_detector.log` WARN |

---

## CLI（无需 HTTP）

```bash
python3 nav_mission_coordinator.py status
python3 nav_mission_coordinator.py resume
python3 nav_mission_coordinator.py teleop 0.2 0 0
```
