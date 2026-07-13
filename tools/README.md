# PC 端工具

## 罗技 G29 控车 `logitech_g29_drive.py`

用 G29 方向盘 + 踏板通过 **TCP 6000** 控制 Rosmaster 麦克纳姆小车，协议与 App 相同，**无需修改 App 或 Jetson 固件**。

### 硬件连接

```
G29 (USB) ──→ 组员 Windows 笔记本
                    │
                    │  WiFi 局域网
                    ▼
              Jetson (ros/run → :6000)
                    │
                    ▼
                 小车底盘
```

### 软件准备

**1. Windows 安装 G29 驱动**

- 安装 [Logitech G HUB](https://www.logitechg.com/software/g-hub) 或官方驱动  
- 设备管理器中能看到 G29

**2. Python 依赖**

```cmd
pip install pygame
```

**3. Jetson 启动控车服务**

```bash
# Jetson 终端
ros/run
ss -tlnp | grep 6000   # 确认在监听
```

### 使用步骤

**Windows G29 若 pygame 轴全为 0，请用 winmm 后端（推荐）：**

```cmd
cd D:\oh-ai-car-ros-app\tools
python logitech_g29_drive.py --backend winmm --calibrate
python logitech_g29_drive.py --backend winmm --ip 10.147.13.194 --max-speed 30
```

标定前建议 **完全退出 G HUB**（系统托盘 → 退出），避免独占方向盘。

**1. 标定轴位（首次建议）**

```cmd
cd D:\oh-ai-car-ros-app\tools
python logitech_g29_drive.py --calibrate
```

转动方向盘、踩油门/刹车，确认：

| 输入 | 预期 |
|------|------|
| 方向盘 | `steer` 在 -1～+1 变化 |
| 油门 | `throttle` 增大 |
| 刹车 | `throttle` 减小或为负 |

若轴号不同，修改脚本顶部 `AXIS_STEER` / `AXIS_GAS` / `AXIS_BRAKE`。

**2. 踏板控车（默认，同 App 前进/停止键）**

```cmd
python logitech_g29_drive.py --backend winmm --mode pedal --ip 10.147.13.194
```

**3. 比例油门弧线行驶（需踏板）**

```cmd
python logitech_g29_drive.py --backend winmm --mode drive --max-speed 30
```

**4. 操作说明（`--mode pedal` 默认）**

| G29 输入（左→右） | 小车动作 | 协议 |
|-------------------|----------|------|
| **离合（左）** | 后退 | cmd15 dir=2 |
| **刹车（中）** | 停止 | cmd15 dir=0 |
| **油门（右）** | 前进 | cmd15 dir=1 |
| 方向盘（未踩踏板） | 左/右原地旋转 | cmd15 dir=5/6 |
| 红色按钮 | 急停 | cmd15 dir=0 |

优先级：刹车 > 离合 > 油门。

**5. 仅方向盘旋转（不测踏板）**

```cmd
python logitech_g29_drive.py --backend winmm --mode rotate --max-turn 55 --ip 10.147.13.194
```

### 控制模式

| 模式 | 协议 | 说明 |
|------|------|------|
| **`pedal`（默认）** | cmd 15 | 油门=前进、刹车=停止，同 App 按键 |
| `rotate` | cmd 15 | 仅方向盘原地转，不需踏板 |
| `drive` | cmd 21 | 比例油门+转向弧线 |
| `arcade` | cmd 10 | 前后+平移 |

```cmd
python logitech_g29_drive.py --backend winmm --mode pedal --ip 10.147.13.194
python logitech_g29_drive.py --backend winmm --mode rotate --max-turn 55
python logitech_g29_drive.py --mode drive --max-speed 40
```

踏板不灵敏时调 `--pedal-threshold 0.08`（默认 0.12）。

### 安全提示

- 首次 `--max-speed 20～30`，熟悉后再加大  
- 在空旷场地测试，随时准备 **Ctrl+C** 或按 **红色急停**  
- 不要与 Docker 自主导航 **n3** 同时抢底盘  
- 可与巡检 `6700` 并行（不占 6000 摄像头冲突；但 ros/run 与 patrol 摄像头仍互斥）

### 常见问题

| 现象 | 处理 |
|------|------|
| 未检测到方向盘 | 检查 USB、G HUB、换 USB 口 |
| TCP 连接失败 | Jetson 上 `ros/run`；防火墙；IP 是否正确 |
| 只有前进不会转 | 加大 `--max-turn`；确认 `--mode drive` |
| 踏板无反应 | `--calibrate` 看 gas/brake；试 `--pedal-direct` 或 `--pedal-threshold 0.08` |
| 车反应迟钝 | 提高 `--hz 30` |

### 与 App 的关系

- App 遥控与 G29 脚本**共用 TCP 6000**，**不要同时**从 App 和 G29 发指令  
- 答辩可演示：「App 巡检看事件 + PC 方向盘现场控车」分场景展示

---

## 罗技 G29 mission 绕障 `g29_mission_drive.py`

Docker 导航 **n1/n2/n3 + mission 告警停车** 后，用 G29 人工绕障。走 **HTTP 6700 `/mission/teleop` → Docker `/cmd_vel`**，**不走 TCP 6000**，不与 n1 抢串口。

### 连接示意

```
G29 (USB) ──→ Windows PC (本脚本)
                    │
                    │  WiFi  POST :6700/mission/teleop
                    ▼
              Jetson patrol_server
                    │
                    │  docker exec → /cmd_vel
                    ▼
              Docker n1 底盘（Nav2 已暂停）
```

### 前置条件（Jetson）

```bash
bash start_nav_docker.sh
bash start_mission_nav.sh
# RViz 设点导航 → 路上检出瓶子/椅子 → 小车 alert_stopped 停车
```

### Windows 用法

```cmd
cd D:\oh-ai-car-ros-app\tools
python g29_mission_drive.py --backend winmm --calibrate
python g29_mission_drive.py --backend winmm --ip 10.147.13.194 --mode pedal
```

**测试 teleop（不插方向盘）**

```cmd
python g29_mission_drive.py --ip 10.147.13.194 --test-forward
```

### 踏板映射（默认 `--mode pedal`）

| G29 | cmd_vel |
|-----|---------|
| 油门 | 前进 `vx` |
| 离合 | 后退 `vx` |
| 刹车 | 停车 |
| 方向盘 | 转弯 `wz` |

速度单位 m/s、rad/s，默认 `--max-linear 0.15`、`--max-angular 0.45`。场地大可略增，首次建议保持默认。

### 绕障完成后恢复自动导航

```cmd
curl -X POST http://10.147.13.194:6700/mission/resume
```

### 与 `logitech_g29_drive.py` 对比

| 脚本 | 通路 | 适用场景 |
|------|------|----------|
| `logitech_g29_drive.py` | TCP 6000 | 无 Docker 导航，需 `ros/run` |
| `g29_mission_drive.py` | HTTP 6700 teleop | **mission 模式** n1 在跑、告警后绕障 |

### 常见问题

| 现象 | 处理 |
|------|------|
| teleop 被拒 | 须先 YOLO 告警停车，`state=alert_stopped` |
| 连接 6700 失败 | 小车 `bash start_mission_nav.sh` |
| 车不动 | `--test-forward` 测通路；加大 `--max-linear` |
| 和 TCP 版搞混 | mission 绕障**只用** `g29_mission_drive.py` |
