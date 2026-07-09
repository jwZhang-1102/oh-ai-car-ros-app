# 智慧小车遥控 App（OpenHarmony）

基于 OpenHarmony / ArkTS 开发的智慧小车遥控应用，通过 TCP 协议控制 Rosmaster 小车，并通过 HTTP 拉取车载摄像头画面。

- **包名**：`com.hoperun.cmartcar`
- **目标平台**：OpenHarmony API 12（`runtimeOS: "OpenHarmony"`）
- **通信协议**：详见 [ros_api.md](./doc/ros_api.md)

## 功能概览

| 功能 | 说明 |
|------|------|
| 网络配置 | 设置小车 IP、TCP 端口、视频端口，连接成功后进入主页 |
| 遥控驾驶 | 摇杆 + 方向按钮控制小车前进/后退/平移/旋转 |
| 麦克纳姆轮 | 四轮独立速度控制（cmd 20/21） |
| 实时视频 | Web 组件加载 `http://{ip}:{port}/index2` 直播画面 |
| 偏好存储 | IP 与端口通过 Preferences 持久化 |

当前版本为**单车连接**模式：`TCPClientManager` 单例维护一条 TCP 连接，所有控车指令经 `CarApi` 发送。

## 网络与默认配置

| 项目 | 默认值 | 说明 |
|------|--------|------|
| 小车 IP | `10.147.13.194` | 可在网络配置页修改，并写入 Preferences |
| TCP 端口 | `6000` | 控车指令，协议格式 `$...#` |
| 视频端口 | `6500` | HTTP 直播，路径 `/index2` |

**使用前请确保**：手机/平板与小车处于同一局域网，且 Jetson 上 TCP（6000）与视频（6500）服务已启动。

```bash
# Jetson 上检查服务（示例）
ss -tlnp | grep 6000
ss -tlnp | grep 6500
curl -I http://127.0.0.1:6500/index2   # 应返回 200
```

## 架构说明

```
App（ArkTS）
  └─ CarApi.send()
       └─ TCPClientManager（单连接单例）→ TCP :6000
            └─ Jetson Rosmaster 应用
                 └─ 串口 → 底盘 MCU → 电机
```

视频流不经过 TCP，由 `VideoComponents` 内 Web 组件直接访问 `http://{ip}:6500/index2`。

## 开发环境

推荐使用 **DevEco Studio 6.1** 及 **OpenHarmony SDK API 12**。

```
DevEco Studio 6.1
OpenHarmony SDK API 12
Node.js（随 DevEco 自带或自行配置）
```

### 本地配置

1. **SDK 路径**：在项目根目录创建 `local.properties`（已加入 `.gitignore`），例如：

   ```properties
   sdk.dir=D:/OpenHarmonySDK
   nodejs.dir=C:/path/to/nodejs
   ```

   若 DevEco 提示将 SDK 路径改为 `D:/OpenHarmonySDK`，请接受该建议。

2. **编译配置**：`build-profile.json5` 中 `compileSdkVersion` / `compatibleSdkVersion` / `targetSdkVersion` 须为整数 `12`，且 `runtimeOS` 为 `"OpenHarmony"`（不可使用 `"5.0.0(12)"` 这类字符串）。

3. **设备能力**：`entry/src/main/syscap.json` 已移除部分真机不支持的 SysCap，以提升在 OpenHarmony 设备上的兼容性。

4. **构建守护进程**：`hvigor/hvigor-config.json5` 中 `daemon: false`，避免多进程占用 `.hvigor` 导致 `EPERM` 构建失败。

### 签名

使用 DevEco 自动生成的 OpenHarmony 调试签名即可本地安装。签名材料路径配置在 `build-profile.json5` 的 `signingConfigs` 中。

## 运行与调试

1. 用 USB 连接 **OpenHarmony 真机**（推荐）；模拟器对 OpenHarmony 项目支持有限，可能出现 `devices is null` 或无法安装。
2. 运行配置中 **Module** 选择 `entry`（勿留空，否则可能报 `00401008`）。
3. 启动后进入网络配置页，填写小车 IP 并连接；连接成功跳转主页，再进入遥控或麦克纳姆轮页面。
4. 应用横屏运行（`module.json5` 中 `orientation: landscape`）。

### 常见问题

| 现象 | 处理建议 |
|------|----------|
| `EPERM` / `build.log` 被占用 | 关闭多余 DevEco/Cursor 窗口，结束 node 进程，删除 `.hvigor` 后重新构建 |
| `00401008` 模块错误 | 运行配置 Module 设为 `entry` |
| `devices is null` | 选择已就绪的真机，或等待设备连接 |
| 摇杆区域空白但可触控 | 已改为默认圆形绘制（不依赖 SVG ImageBitmap），属预期表现 |
| 视频黑屏 | 检查 6500 服务、IP/端口、手机与小车是否同网 |
| Cursor 报 `hvigor-ohos-plugin` 找不到 | IDE 类型检查问题，DevEco 内构建通常仍可成功 |

## Jetson 小车侧说明

- **控车**：需先启动 Rosmaster TCP 服务（端口 6000）。
- **视频**：摄像头服务监听 6500；若 `/dev/camera_depth` 不存在，可临时 `ln -s video0`，或修改 `camera_rosmaster.py` / `camera_server.py` 使用 `/dev/video0`。
- **YOLO 等脚本**：`object_tracking_lite.py` 等依赖 TCP 服务在线才能联动控车。

## 项目原型图

### 网络配置界面（NetworkSettings）

![NetworkSettings.png](./doc/prototype/NetworkSettings.png)

### 主页界面（Index）

![Index.png](./doc/prototype/Index.png)

### 麦克纳姆轮界面（MecanumWheel）

![MecanumWheel.png](./doc/prototype/MecanumWheel.png)

### 控制界面状态1（RemoteControl1）

![RemoteControl1.png](./doc/prototype/RemoteControl1.png)

### 控制界面状态2（RemoteControl2）

![RemoteControl2.png](./doc/prototype/RemoteControl2.png)

## ROS / HTTP API

- **TCP 控车协议**：[doc/ros_api.md](./doc/ros_api.md)（端口 6000，`$cmd...#` 帧格式）
- **HTTP 视频**：`GET http://{小车IP}:6500/index2`，由 App 内 Web 组件展示，无额外 REST 封装

## 文件结构

```
oh-ai-car-ros-app
├─ AppScope
│  └─ app.json5                    # 应用包名与版本
├─ doc
│  ├─ prototype/                   # 界面原型图
│  └─ ros_api.md                   # TCP 协议文档
├─ entry
│  └─ src/main
│     ├─ ets
│     │  ├─ CarUtill/              # 控车 API、编码、枚举
│     │  ├─ components/            # 摇杆、按钮、视频组件
│     │  ├─ pages/                 # 网络配置、主页、遥控、麦轮
│     │  ├─ tcp/                   # TCPClientManager 单例连接
│     │  └─ utils/                 # Preferences、屏幕等工具
│     ├─ syscap.json               # 设备能力裁剪
│     └─ module.json5              # 模块配置与 INTERNET 权限
├─ Rocker/                         # 摇杆子模块（Canvas 摇杆）
├─ build-profile.json5             # SDK 12 / OpenHarmony 编译配置
├─ hvigor/hvigor-config.json5
└─ readme.md
```

## 后续规划

- **多车同步遥控**：App 侧多 TCP 连接 + 指令广播；视频仍只显示主车画面；连接策略为「连上几辆控几辆」。尚未合入当前代码。
