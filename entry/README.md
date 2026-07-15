# entry 模块说明（OpenHarmony App）

本目录为「智检哨兵」鸿蒙应用的主模块（`entry`），负责网络配置、TCP 控车、视频预览、智能巡检页等界面与业务逻辑。摇杆 UI 来自同级仓库的 `Rocker` HAR 依赖。

能力范围与终期答辩 PPT 一致：**控车、视频、巡检事件查阅**。不含危险区域地图标点、mission 任务编排等未交付能力。

---

## 依赖与运行

| 项 | 说明 |
|------|------|
| 模块名 | `entry` |
| 依赖 | `"rocker": "file:../Rocker"`（见 `oh-package.json5`） |
| 目标 | OpenHarmony API 12 |
| 开发 | DevEco Studio，运行配置 Module = `entry` |

工程根目录配置 `local.properties`（`sdk.dir`、`nodejs.dir`），详情见仓库根目录 [readme.md](../readme.md)。

---

## 页面一览

注册于 `src/main/resources/base/profile/main_pages.json`：

| 页面 | 路径 | 作用 |
|------|------|------|
| 网络配置 | `pages/NetworkSettings` | 填写 IP / 端口，勾选 TCP、视频、巡检；巡检模式入口 |
| 主页 | `pages/Index` | 连接状态、功能入口卡片、断开连接 |
| 麦克纳姆轮 | `pages/MecanumWheel` | 四轮速度控车 |
| 单独遥控 | `pages/RemoteControl` | 摇杆 + 方向键控车 |
| 智能巡检 | `pages/PatrolPage` | 拉取 6700 事件列表、截图、自动刷新 |
| 全景/驾驶 | `pages/PanoramicView` | 视频驾驶视图（MJPEG） |

---

## 源码结构

```
entry/src/main/ets/
├─ entryability/EntryAbility.ets   # 应用入口
├─ pages/                          # 上述页面
├─ components/
│  ├─ CarRockerComponents.ets      # 封装 Rocker，发送摇杆指令
│  ├─ CarBtnComponents.ets         # 方向键：按下移动、松开停止
│  ├─ VideoComponents.ets          # 视频组件
│  └─ PageHeader.ets
├─ CarUtill/
│  ├─ CarApi.ets                   # 控车 API
│  ├─ CarEncode.ets                # 协议帧编码
│  └─ CarEnum.ets
├─ tcp/
│  ├─ TCPClientManager.ets         # 单例 TCP 连接（6000）
│  ├─ TCPClientSendUtils.ets
│  └─ TCPClientReceiveUtils.ets
├─ patrol/
│  ├─ PatrolApi.ets                # /health、/events、/snapshot
│  └─ PatrolEventModel.ets         # 事件数据模型
└─ utils/
   ├─ PreferencesUtils.ets         # IP / 端口 / 开关持久化
   ├─ MjpegFramePoller.ets         # MJPEG 拉帧与最新帧解析
   ├─ VideoConfig.ets
   ├─ ScreenUtils.ets
   └─ MyUtils.ets
```

---

## 与小车的通信

| 通道 | 默认端口 | 用途 | 开关（网络配置页） |
|------|----------|------|-------------------|
| TCP | **6000** | 控车指令（与 G29 同协议） | 启用 TCP |
| HTTP | **6500** | MJPEG 视频 | 启用视频 |
| HTTP | **6700** | 巡检健康检查 / 事件 / 截图 | 启用巡检 / 巡检模式 |

协议细节：[doc/ros_api.md](../doc/ros_api.md)。

**连接策略（摘要）**

- 可按场景只开巡检（只访问 6700），或开 TCP+视频做遥控。
- 任一启用的服务成功即可进入主页；全部失败则 Toast 提示。
- 巡防演示阶段推荐「巡检模式」：不要连 6000（此时 Jetson 通常在跑 Docker 导航，未启 `ros/run`）。

---

## 使用注意（与 Jetson 模式对应）

| App 场景 | Jetson 侧前提 |
|----------|----------------|
| 智能巡检 | 已 `start_patrol_host.sh --bg`，6700 可用；可与导航并行 |
| 遥控 / 麦轮 / 全景视频 | 已停导航容器，已 `ros/run`（6000，及通常 6500） |
| 视频 | 勿与 YOLO 巡检同时占用摄像头 |

勿与 PC 端 G29 **同时**控车（共用 6000）。

完整操作步骤见 [智能小车操作手册.md](../智能小车操作手册.md)。

---

## 本地自检建议

1. 网络页填对小车 IP，保存后看主页连接状态。  
2. 遥控：点按方向键，松开应变停止。  
3. 巡检：`curl http://<IP>:6700/health` 通后，列表应能刷到事件并打开截图。  
4. 视频黑屏：查 6500，并确认未与巡检抢摄像头。

---

## 相关文档

- 仓库总览：[readme.md](../readme.md)
- Jetson 侧：[jetson/README.md](../jetson/README.md)
- 巡检脚本：[jetson/patrol/README.md](../jetson/patrol/README.md)
- G29（PC）：[tools/README.md](../tools/README.md)
