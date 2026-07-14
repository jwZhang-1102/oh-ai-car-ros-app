# 让 `ros/run` 顺带启动 6700（App 看告警）

## 推荐：`app2.py` + 改 `start_app.sh`

`run` 实际是 `~/Rosmaster-App/rosmaster/start_app.sh` → `app.py`。

仓库已提供：

| 文件 | 作用 |
|------|------|
| `app2.py` | 启动 6700（复用 `patrol_server.py`） |
| `start_app.sh` | 同时起 `app.py` + `app2.py` |

```cmd
cd /d D:\oh-ai-car-ros-app
scp jetson/patrol/app2.py jetson/patrol/start_app.sh jetson/patrol/patrol_server.py jetson/patrol/nav_mission_coordinator.py jetson@10.147.13.194:~/Rosmaster-App/rosmaster/
```

Jetson：

```bash
cd ~/Rosmaster-App/rosmaster
cp -a start_app.sh start_app.sh.bak.$(date +%Y%m%d)   # 若还没备份原厂
# 确认已用仓库里的 start_app.sh（含 app2）
sed -i 's/\r$//' start_app.sh
chmod +x start_app.sh app2.py
# 依赖：flask；若缺 coordinator 相关模块需一并 scp
ros/run
ss -tlnp | grep -E '6000|6500|6700'
curl -sf http://127.0.0.1:6700/health
```

---

## 先分清两件事

| 端口/进程 | 作用 | 能否跟 `run` 一起开 |
|-----------|------|---------------------|
| **6000** | TCP 遥控（`run` 已有） | ✅ |
| **6500** | 实时视频（`run` 已有，占摄像头） | ✅ |
| **6700** `patrol_server` | App 拉事件列表/截图 | ✅ **可以挂到 run** |
| **YOLO** `patrol_detector` | **产生新告警**（写 events） | ❌ 与 6500 **抢摄像头** |

所以：

- **只想 App 能打开智能巡检、看已有/之后写入的事件** → `run` 里加 **6700** 即可。  
- **想边 App 看直播(6500) 边实时 YOLO 出新告警** → 当前架构做不到，仍用「巡检模式」：`start_patrol_host.sh`（关视频）。

---

## 改法（Jetson 上改 Yahboom 的 `run`）

### 1. 上传脚本

PC：

```cmd
cd /d D:\oh-ai-car-ros-app
scp jetson/patrol/start_patrol_http.sh jetson/patrol/patrol_server.py jetson@10.147.13.194:~/Rosmaster-App/rosmaster/
```

Jetson：

```bash
cd ~/Rosmaster-App/rosmaster
sed -i 's/\r$//' start_patrol_http.sh
chmod +x start_patrol_http.sh
```

### 2. 找到并备份 `run`

```bash
type run
# 或
which run
ls -la ~/Rosmaster-App/rosmaster/run*
```

常见是工作目录下可执行文件 `run`。先备份：

```bash
cd ~/Rosmaster-App/rosmaster
cp -a run run.bak.$(date +%Y%m%d)
```

### 3. 在 `run` 末尾加一行

```bash
nano run   # 或 vi run
```

在脚本**最后**（启动 6000/6500 的逻辑之后）追加：

```bash
# 智检哨兵：App 6700（仅 HTTP，不启 YOLO，不抢摄像头）
bash "$HOME/Rosmaster-App/rosmaster/start_patrol_http.sh" || true
```

保存退出。

### 4. 验证

```bash
ros/run
# 另开终端：
ss -tlnp | grep -E '6000|6500|6700'
curl -sf http://127.0.0.1:6700/health
curl -sf http://127.0.0.1:6700/events | head
```

App：填 IP → 可「连接小车」或巡检模式 → **智能巡检** 刷新。

---

## 新告警从哪来？

挂到 `run` 后，**App 能连 6700**，但若未跑 YOLO：

- 只能看到 `events.jsonl` 里**已有**事件；  
- **新告警**仍要另开巡检（会占摄像头，需停 6500）：

```bash
bash stop_camera_server.sh   # 若 run 占着摄像头
bash start_patrol_host.sh --bg
```

或答辩时用两套模式切换：遥控+视频用 `run`；巡检出告警用 `start_patrol_host.sh`。

---

## 还原

```bash
cd ~/Rosmaster-App/rosmaster
cp -a run.bak.* run   # 选对应备份
# 或删掉追加的那两行
pkill -f patrol_server.py
```
