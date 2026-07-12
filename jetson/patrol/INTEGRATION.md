# 智检哨兵 Day3：导航 + 巡检 + App 联调

目标：**小车按地图自主跑 + YOLO 边检边记 + App 准实时看事件**

---

## 架构（三块并行）

| 模块 | 跑在哪 | 端口/资源 | 作用 |
|------|--------|-----------|------|
| Docker 导航 `n1`+`n3` | autodrive 容器 | 雷达 | 按地图自主走 |
| `patrol_detector.py` | 宿主机 | 摄像头 | YOLO 检测 |
| `patrol_server.py` | 宿主机 | **6700** | App 拉事件/截图 |

**不要**同时开：`ros/run`、6500 视频推流（占摄像头）。

App 用 **「保存并进入（巡检模式）」**，不需要 6000/6500。

---

## 答辩 Demo 步骤（约 15 分钟）

### A. 准备地图（已完成可跳过）

手册 3.7：`m1`→`m2`→`m3` 建图 → `m4` 保存。

### B. 启动 Docker 自主导航

```bash
# 宿主机
s          # 启动 autodrive 容器
d          # 进入容器

# 容器内（两个终端）
n1         # 导航基础
n3         # DWA 导航（或 n4 TEB）
n2         # RViz 展示（可选，设位姿/目标点）
```

RViz：**2D Pose Estimate** 设初始位姿 → **2D Goal Pose** 设目标点 → 小车自己走。

### C. 宿主机启动巡检（另开 SSH，不在 Docker 里）

```bash
cd ~/Rosmaster-App/rosmaster
# 从仓库复制脚本后：
bash start_patrol_host.sh
```

或手动：

```bash
bash stop_camera_server.sh    # 释放摄像头
nohup python3 patrol_server.py > patrol_server.log 2>&1 &
python3 patrol_detector.py    # 或 nohup 后台
```

验证：

```bash
curl http://127.0.0.1:6700/health
curl http://127.0.0.1:6700/events
```

### D. App

1. 填小车 IP → **保存并进入（巡检模式）**
2. **智能巡检** → 打开 **自动刷新（4 秒）**
3. 小车导航过程中，新检测到目标会自动出现在列表

---

## 文件清单（Jetson `~/Rosmaster-App/rosmaster/`）

| 文件 | 来源 |
|------|------|
| `patrol_server.py` | 仓库 `jetson/patrol/` |
| `patrol_detector.py` | Day1 已在 Jetson 创建 |
| `events.jsonl` | detector 运行时生成 |
| `capture/patrol/*.jpg` | detector 截图 |
| `start_patrol_host.sh` | 仓库 `jetson/patrol/` |
| `danger_zones.json` | RViz 标定危险多边形 |
| `danger_zone_utils.py` | 多边形判断 |
| `pose_reader.py` | 订阅 `/amcl_pose` |
| `rosmaster_buzzer.py` | 蜂鸣器控制 |

从 Windows 上传：

```powershell
scp jetson/patrol/patrol_server.py jetson/patrol/start_patrol_host.sh jetson/patrol/stop_patrol_host.sh jetson@10.147.13.194:~/Rosmaster-App/rosmaster/
```

---

## 多航点巡航（可选增强）

手册默认 RViz **手点一个目标**。若要自动循环：

1. 在 RViz 记录 2～3 个目标点坐标（map 坐标系）
2. 容器内写 ROS2 节点，依次 `publish` `/goal_pose`（话题名以 `ros2 topic list` 为准）
3. 到达后再发下一个点

MVP 答辩可先用 **手点 2～3 次目标** + 全程巡检，已能说明「自主导航 + 智能检测 + App 留痕」。

---

## 常见问题

| 现象 | 处理 |
|------|------|
| detector 读帧失败 0x0 | `stop_camera_server.sh`，勿开 ros/run |
| App 无事件 | `curl .../events`；确认 6700 在跑 |
| 导航不动 | RViz 重设 2D Pose Estimate |
| Docker 与 detector 冲突 | 导航用雷达；detector 用 USB 摄像头，一般可并行 |
| **并行时无绿路径 / 不走** | 宿主机 `docker exec` 轮询 `/amcl_pose` + YOLO 占算力 → **`--skip-pose --nav-lite`**（`start_patrol_host.sh` 已默认） |
| **停巡检能走、开巡检不能** | 同上；串口空闲则不是 Rosmaster 冲突 |

---

## Docker 导航 + 巡检 并行（已验证）

**根因（实测）**：后台持续 `docker exec` 读 `/amcl_pose` 叠加 YOLO，拖垮 Nav2。**办法**：`--pose-on-demand`——仅在 person 告警时读一次位姿，危险区判断保留且不影响导航。

**推荐启动（导航 + 巡检 + 危险区）**：

```bash
# 容器：n1 → n2 → n3，RViz 2D Pose Estimate
# 宿主机：
cd ~/Rosmaster-App/rosmaster
bash start_patrol_host.sh --bg
# 默认：--docker-nav --pose-on-demand --nav-lite
```

| 并行可用 | 说明 |
|----------|------|
| 自主导航 + 绿路径 | ✅ |
| YOLO `[ALERT]` + App 6700 | ✅ |
| 车在危险区 + person → `[DANGER]` | ✅ on-demand 读位姿 |
| 蜂鸣器 | 并行时多不可用（不占串口/无6000），事件与日志仍有 |

**注意**：当前规则是「车在危险区 + 看到 person」，不是「人在危险区」。地理精度提升需深度投影（后续）。

---

## Docker 导航 + 巡检 并行（重要）

`n1` 在容器里通过 **串口** 控制底盘。旧版宿主机 `patrol_detector` 初始化 `Rosmaster_Lib` 会 **抢占同一串口**；即使不占串口，**YOLO + 高频 docker 位姿轮询** 也可能让 DWA 规划正常但 **cmd_vel 执行断续**。

**正确启动（新版 `start_patrol_host.sh` 已默认安全，无需手写 `--docker-nav`）：**

```bash
# 终端1 容器：n1 → n2 → n3
# 终端2 宿主机（不要 ros/run）：
cd ~/Rosmaster-App/rosmaster
bash start_patrol_host.sh --bg

# 导航仍卡/不走：
bash start_patrol_host.sh --nav-lite --bg
```

**仅单机巡检要蜂鸣**（勿与 Docker 导航同时）：

```bash
bash start_patrol_host.sh --buzzer-serial
```

**隔离排查（定位是串口还是算力）：**

```bash
# A. 只导航 — 必须能走到 Goal
# B. 只起 HTTP，不起 detector：
nohup python3 patrol_server.py > patrol_server.log 2>&1 &
#    若 B 仍影响导航 → 不是巡检问题，查 n1/n3
# C. 最简 detector（不占串口、不读位姿）：
python3 patrol_detector.py --no-zones --no-buzzer
#    若 C 影响导航 → YOLO 算力问题，用 --nav-lite
# D. 全功能并行：
bash check_nav_parallel.sh
```

| 可同时 | 不可同时 |
|--------|----------|
| Docker n1+n3 + 巡检 6700/YOLO | 宿主机 `ros/run`（TCP 6000）+ Docker 导航 |
| 雷达（容器）+ 摄像头（宿主机） | `--buzzer-serial` + Docker n1 |
| App 巡检页 6700 | 6500 视频 + YOLO（抢摄像头） |

并行时 **危险区蜂鸣** 可能不可用；`[ALERT]` / App 事件仍正常。

### n3 终端一片红字 / lifecycle_manager 报错

若日志里大量出现 `signal_handler(signal_value=2)`、`context is not valid`、`Failed to change state for node: controller_server`，**多数是 n3 已被 Ctrl+C 中断或 launch 正在退出**，红字往往是 **Foxy 关停时的连锁报错**，不一定是根因。

请向上翻找 **第一次** 出现的 `[ERROR]`（在 `signal_handler` 之前），或按下面 **干净重启** 再抓完整启动日志：

```bash
# 容器内：先停旧进程（各 n1/n3 窗口 Ctrl+C），确认无残留
ps aux | grep -E 'navigation_dwa|controller_server|laser_bringup' | grep -v grep

# 宿主机：串口不要被巡检占用（并行必用 --docker-nav）
fuser /dev/myserial 2>/dev/null || true

# 推荐顺序（与手册一致）：n1 → 等话题就绪 → n2 → n3
n1
# 另开终端验证（约 10～20 秒后再 n3）：
ros2 topic list | grep -E 'scan|odom|cmd_vel'
ros2 topic hz /scan --window 5

n2    # RViz
n3    # 成功时应持续运行，不要立刻 Ctrl+C
```

| 启动失败常见原因 | 处理 |
|------------------|------|
| **n1 未先起或已挂** | 先 n1，确认 `/scan`、`/odom` 有数据再 n3 |
| **宿主机占串口** | 停巡检或 `bash start_patrol_host.sh --docker-nav`；勿 `ros/run` |
| **重复启动 n3** | 旧 launch 未杀干净 → 全窗口 Ctrl+C 后等 5 秒再起 |
| **地图/参数** | n3 窗口最前面应有 map_server/amcl 正常 `[INFO]`，无 `map file` 报错 |

n3 **正常运行** 时进程不会退出，终端应停在一串 `[INFO]` 上；只有按 **Ctrl+C** 或 bringup **失败中止** 才会出现你贴的那段退出日志。


在 RViz 用 **Publish Point** 点选多边形顶点，保存为 `danger_zones.json`（与 `patrol_detector.py` 同目录）。

```bash
# 宿主机 ~/Rosmaster-App/rosmaster/
ls danger_zones.json   # 确认存在
bash start_patrol_host.sh
```

**逻辑**：YOLO 连续检出 `person` + 小车 **map 位姿**落在危险多边形内 → 蜂鸣器响（`set_beep` / TCP cmd=13）。

| 条件 | 说明 |
|------|------|
| Docker `n1` 导航 | 发布 `/amcl_pose`，宿主机 detector 订阅 |
| `danger_zones.json` | RViz 四角坐标，`frame: map` |
| 蜂鸣器 | `ros/run`（Rosmaster_Lib）或 TCP 6000 在线 |
| 日志 | `[DANGER]` = 危险区内 person + 蜂鸣；`[ALERT]` = 普通检测 |

调试：

```bash
# 容器内确认位姿话题
ros2 topic echo /amcl_pose --once

# 前台看位姿 + 区域（--verbose 每 30 帧打印 pose）
python3 -u patrol_detector.py --verbose --targets person
```

---

## 分工建议

- **B**：Docker `n1/n3` + RViz 设点 + 标危险区  
- **A**：`patrol_detector` 调 TARGETS / COOLDOWN / 危险区  
- **C**：`start_patrol_host.sh` 联调  
- **D**：App 自动刷新（已实现）  
- **E**：Demo 脚本 + 答辩话术  
