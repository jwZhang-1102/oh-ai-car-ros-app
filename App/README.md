# 智检哨兵 · OpenHarmony App

面向「智检哨兵」小车的鸿蒙客户端：局域网连接 Jetson，完成 **遥控控车、视频预览、巡检告警查阅**。

能力与终期答辩 PPT 中的「OpenHarmony APP」一致；不含危险区域地图、mission 任务等未交付功能。

| 项 | 说明 |
|------|------|
| 包名 | `com.hoperun.cmartcar`（见 `AppScope/app.json5`） |
| 平台 | OpenHarmony API 12 |
| 默认小车 IP | `10.147.13.194`（网络配置页可改） |
| 工程主模块 | [`entry/`](../entry/) |
| 摇杆子模块 | [`Rocker/`](../Rocker/)（HAR，本地依赖） |

---

## 你能用 App 做什么

| 功能 | 说明 |
|------|------|
| 网络配置 | 填写 IP、TCP/视频/巡检端口；勾选启用项；支持「巡检模式」一键进入 |
| 麦轮 / 遥控 | 摇杆、方向键发控车指令；松手即停 |
| 视频 / 全景驾驶 | HTTP MJPEG 实时画面（端口 6500） |
| 智能巡检 | 轮询 6700 事件列表、置信度分级、查看告警截图 |
| 断开连接 | 关闭 TCP 并回到配置页 |

---

## 使用前：小车侧模式（必读）

App **不能**替代小车侧启停。请先按场景准备 Jetson：

| 想用的 App 功能 | 小车侧需要 |
|-----------------|------------|
| **智能巡检**（推荐答辩主场景） | `start_patrol_host.sh --bg`，6700 正常；可与 Docker 导航并行。App 用「巡检模式」，不必开 TCP |
| **遥控 / 麦轮 / 看视频** | 先停导航容器，再 `ros/run`（6000 + 通常 6500）。需要画面时勿与 YOLO 抢摄像头 |
| 与 G29 同时控车 | **不要**——共用 TCP 6000 |

完整步骤：[智能小车操作手册.md](../智能小车操作手册.md)、[jetson/README.md](../jetson/README.md)。

---

## 快速上手（手机）

1. 用 DevEco 安装并运行本工程（Module = `entry`），或安装已签名 HAP。  
2. 手机与小车同一 Wi-Fi。  
3. 打开 App → **连接小车**：
   - **只看告警**：填 IP →「保存并进入（巡检模式）」→ 主页进「智能巡检」。  
   - **开车 + 看画面**：填 IP，勾选 TCP、视频 → 保存并进入 → 选麦轮/遥控/全景。  
4. 主页可随时断开连接返回配置页。

---

## 端口一览

| 端口 | 协议 | App 用途 |
|------|------|----------|
| 6000 | TCP | 控车 |
| 6500 | HTTP | 视频 |
| 6700 | HTTP | `/health`、`/events`、截图 |

协议说明：[doc/ros_api.md](../doc/ros_api.md)。

---

## 工程结构（App 相关）

```
oh-ai-car-ros-app/
├─ AppScope/                 # 应用级配置与资源
│  └─ app.json5              # bundleName 等
├─ entry/                    # 主模块：页面与业务（详见 entry/README.md）
│  └─ src/main/ets/
│     ├─ pages/              # 网络配置、主页、遥控、巡检、全景…
│     ├─ tcp/ / patrol/ / CarUtill/ / components/ / utils/
├─ Rocker/                   # 摇杆 HAR，entry 通过 oh-package 本地引用
├─ App/README.md             # 本文件（App 使用与总览）
└─ build-profile.json5       # 编译 SDK / 签名产品配置
```

模块级源码说明请看：[entry/README.md](../entry/README.md)。

---

## 主要页面与入口

| 页面 | 作用 |
|------|------|
| NetworkSettings | 连接参数与模式选择（应用启动页） |
| Index | 功能入口：麦轮、遥控、巡检、全景；断开 |
| MecanumWheel | 麦克纳姆轮控车 |
| RemoteControl | 摇杆 + 方向键 |
| PatrolPage | 巡检事件与截图 |
| PanoramicView | 驾驶/视频视图 |

原型图见仓库根 [readme.md](../readme.md)「项目原型图」一节，或 `doc/prototype/`。

---

## 开发与安装

1. 安装 DevEco Studio，配置 OpenHarmony SDK API 12。  
2. 根目录 `local.properties` 配置 `sdk.dir`、`nodejs.dir`。  
3. 打开工程，运行配置选择 Module **`entry`**，连真机调试。  
4. 签名材料在 `signing/`（本地环境路径以 `build-profile.json5` 为准）。  
5. 若提示签名不一致：先卸载手机旧包再重装。

常见问题：

| 现象 | 处理 |
|------|------|
| 连不上 / 不能控车 | IP、同网；遥控场景是否已 `ros/run` 且停了导航 |
| 巡检列表空 | Jetson `curl :6700/health`；是否开了巡检后台 |
| 视频黑屏 | 6500 是否起来；是否与巡检抢摄像头 |
| 构建 EPERM | 关多余 IDE，清理 `.hvigor` 重编 |

---

## 相关文档

| 文档 | 说明 |
|------|------|
| [entry/README.md](../entry/README.md) | entry 模块源码结构 |
| [jetson/README.md](../jetson/README.md) | 小车端脚本 |
| [tools/README.md](../tools/README.md) | PC 端 G29（非本 App） |
| [readme.md](../readme.md) | 仓库总览 |
| `用户手册.docx` | 提交用用户说明 |
