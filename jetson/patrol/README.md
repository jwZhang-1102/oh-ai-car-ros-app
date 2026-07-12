# 智检哨兵 Jetson 脚本

## Day1：`patrol_detector.py`

在 Jetson 上创建并运行（与 `yolov5s.pt` 同目录）：

```bash
cd ~/Rosmaster-App/rosmaster
python3 patrol_detector.py
```

输出：

- `events.jsonl` — 每行一条事件 JSON
- `capture/patrol/*.jpg` — 告警截图

## Day2：`patrol_server.py`

复制到 Jetson：

```bash
scp jetson/patrol/patrol_server.py jetson@<IP>:~/Rosmaster-App/rosmaster/
```

或在小车上用 `cat` 创建同名文件。

```bash
cd ~/Rosmaster-App/rosmaster
pip3 install flask --user
python3 patrol_server.py
```

验证：

- http://\<小车IP\>:6700/events
- http://\<小车IP\>:6700/snapshot/20260712_101017_bottle.jpg

## 注意

- 跑 YOLO / `patrol_detector` 时不要开 `ros/run`（占摄像头）
- `patrol_server` 可与 `patrol_detector` 同时运行（不占摄像头）
- Docker 自主导航（手册 3.7 `n1`+`n3`）可与巡检并行，见 [INTEGRATION.md](./INTEGRATION.md)

## Day3：导航 + 巡检 + App 联调

```bash
# 宿主机一键启动 6700 + YOLO
bash start_patrol_host.sh

# 停止
bash stop_patrol_host.sh
```

完整 Demo 流程见 [INTEGRATION.md](./INTEGRATION.md)。

## 危险区蜂鸣（可选）

1. RViz **Publish Point** 点 4 角 → 写入 `danger_zones.json`
2. Docker 启动 `n1`+`n3` 导航（提供 `/amcl_pose`）
3. 宿主机 `bash start_patrol_host.sh`（自动加载危险区）
4. 小车进入危险区且 YOLO 检出 **person** → 终端 `[DANGER]` + 蜂鸣

```bash
scp jetson/patrol/danger_zones.json jetson/patrol/danger_zone_utils.py \
    jetson/patrol/pose_reader.py jetson/patrol/rosmaster_buzzer.py \
    jetson/patrol/patrol_detector.py jetson/patrol/verify_danger_link.sh \
    jetson@<IP>:~/Rosmaster-App/rosmaster/
```

一键自检（位姿 + 多边形 + 蜂鸣）：

```bash
cd ~/Rosmaster-App/rosmaster
sed -i 's/\r$//' verify_danger_link.sh   # Windows 上传后去 CRLF
bash verify_danger_link.sh
```
