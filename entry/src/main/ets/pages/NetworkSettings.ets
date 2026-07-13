/**
 * 网络设置界面 - 竖屏极简风格
 */
import { TCPClientManager } from '../tcp/TCPClientManager'
import { TCPClientSendUtils } from '../tcp/TCPClientSendUtils'
import promptAction from '@ohos.promptAction'
import router from '@ohos.router'
import { PreferencesUtils } from '../utils/PreferencesUtils'
import { VideoComponents } from '../components/VideoComponents'
import { VideoConfig } from '../utils/VideoConfig'
import { MyUtils } from '../utils/MyUtils'
import { PatrolApi } from '../patrol/PatrolApi'

@Entry
@Component
struct NetworkSettings {
  @State ip: string = '10.147.13.194'
  @State tcpPort: string = '6000'
  @State videoPort: string = '6500'
  @State patrolPort: string = '6700'
  @State enableTcp: boolean = true
  @State enableVideo: boolean = false
  @State enablePatrol: boolean = true
  @State connecting: boolean = false

  aboutToAppear(): void {
    this.readNetConfig()
  }

  build() {
    Column() {
      Row() {
        Text('连接小车')
          .fontSize('18fp')
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_light'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height('56vp')
      .padding({ left: '16vp', right: '16vp' })

      Scroll() {
        Column({ space: '24vp' }) {
          Column({ space: '20vp' }) {
            Column({ space: '8vp' }) {
              Text('小车 IP 地址')
                .fontSize('13fp')
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_secondary'))
              TextInput({ placeholder: '请输入 IP 地址', text: this.ip })
                .width('100%')
                .height('48vp')
                .fontSize('16fp')
                .backgroundColor($r('app.color.edit_text_background'))
                .borderRadius('12vp')
                .padding({ left: '14vp', right: '14vp' })
                .onChange((v: string) => { this.ip = v })
            }

            Column({ space: '10vp' }) {
              PortItem({
                label: '控车 TCP',
                desc: `端口: ${this.tcpPort}`,
                isOn: this.enableTcp,
                defaultPort: this.tcpPort,
                onToggle: (on: boolean) => { this.enableTcp = on },
                onPortChange: (v: string) => { this.tcpPort = v }
              })

              PortItem({
                label: '视频',
                desc: `端口: ${this.videoPort}`,
                isOn: this.enableVideo,
                defaultPort: this.videoPort,
                onToggle: (on: boolean) => { this.enableVideo = on },
                onPortChange: (v: string) => { this.videoPort = v }
              })

              PortItem({
                label: '巡检 HTTP',
                desc: `端口: ${this.patrolPort}`,
                isOn: this.enablePatrol,
                defaultPort: this.patrolPort,
                onToggle: (on: boolean) => { this.enablePatrol = on },
                onPortChange: (v: string) => { this.patrolPort = v }
              })
            }

            Row({ space: '8vp' }) {
              Text('⚠')
                .fontSize('14fp')
              Text('注意：摄像头端口与其它设备可能存在冲突')
                .fontSize('12fp')
                .fontColor('#EF4444')
            }
            .padding('12vp')
            .backgroundColor('#FEF2F2')
            .borderRadius('12vp')
            .width('100%')
          }
          .padding('20vp')
          .backgroundColor($r('app.color.card_background'))
          .borderRadius('16vp')

          Button(this.connecting ? '连接中…' : '连接小车')
            .width('100%')
            .height('52vp')
            .fontSize('17fp')
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.button_background'))
            .borderRadius('16vp')
            .enabled(!this.connecting && (this.enableTcp || this.enableVideo || this.enablePatrol))
            .onClick(() => this.connectSelected())
        }
        .width('100%')
      }
      .layoutWeight(1)
      .padding({ left: '16vp', right: '16vp', bottom: '32vp' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.window_background'))
  }

  private readNetConfig() {
    const netUtils = PreferencesUtils.getInstance().netUtils
    if (!netUtils) return
    netUtils.getIP().then((v) => { this.ip = v as string })
    netUtils.getTcpPort().then((v) => { this.tcpPort = v as string })
    netUtils.getVideoPort().then((v) => { this.videoPort = v as string })
    netUtils.getPatrolPort().then((v) => { this.patrolPort = v as string })
    netUtils.getEnableTcp().then((v) => { this.enableTcp = v as boolean })
    netUtils.getEnableVideo().then((v) => { this.enableVideo = v as boolean })
    netUtils.getEnablePatrol().then((v) => { this.enablePatrol = v as boolean })
  }

  private async saveNetConfig() {
    const netUtils = PreferencesUtils.getInstance().netUtils
    if (!netUtils) return
    netUtils.setIp(this.ip)
    netUtils.setTcpPort(this.tcpPort)
    netUtils.setVideoPort(this.videoPort)
    netUtils.setPatrolPort(this.patrolPort)
    netUtils.setEnableTcp(this.enableTcp)
    netUtils.setEnableVideo(this.enableVideo)
    netUtils.setEnablePatrol(this.enablePatrol)
  }

  private async connectSelected() {
    if (this.enableVideo && this.enablePatrol) {
      promptAction.showToast({ message: '视频与巡检建议不要同时勾选' })
    }
    this.connecting = true
    await this.saveNetConfig()
    VideoConfig.applyFromForm(this.ip, this.videoPort, this.enableVideo)

    let okList: string[] = []
    let failList: string[] = []

    if (this.enableTcp) {
      if (this.tcpPort.trim().length === 0) {
        failList.push('控车(未填端口)')
      } else {
        let tcpOk = await this.tryTcpConnect()
        if (tcpOk) okList.push(`控车:${this.tcpPort}`)
        else failList.push(`控车:${this.tcpPort}`)
      }
    }

    if (this.enableVideo) {
      if (this.videoPort.trim().length === 0) {
        failList.push('视频(未填端口)')
      } else {
        okList.push(`视频:${this.videoPort}`)
      }
    } else {
      VideoComponents.enabled = false
    }

    if (this.enablePatrol) {
      if (this.patrolPort.trim().length === 0) {
        failList.push('巡检(未填端口)')
      } else {
        let port = Number.parseInt(this.patrolPort)
        let patrolOk = await PatrolApi.checkHealth(this.ip, port)
        if (patrolOk) okList.push(`巡检:${this.patrolPort}`)
        else failList.push(`巡检:${this.patrolPort}`)
      }
    }

    this.connecting = false

    if (okList.length > 0) {
      promptAction.showToast({ message: `已连接 ${okList.join(' ')}` })
      router.replaceUrl({ url: 'pages/Index' })
    } else if (failList.length > 0) {
      promptAction.showToast({ message: `连接失败: ${failList.join(' ')}` })
      if (MyUtils.isDebug) {
        router.replaceUrl({ url: 'pages/Index' })
      }
    }
  }

  private async tryTcpConnect(): Promise<boolean> {
    TCPClientManager.getInstance().initNetAddress({
      address: this.ip,
      port: Number.parseInt(this.tcpPort)
    })
    let isConnect = await TCPClientManager.getInstance().connect()
    if (isConnect) TCPClientSendUtils.getInstance().init()
    return isConnect
  }
}

@Component
struct PortItem {
  @Prop label: string = ''
  @Prop desc: string = ''
  @Prop isOn: boolean = true
  @Prop defaultPort: string = '6000'
  @State port: string = ''
  onToggle: (on: boolean) => void = () => {}
  onPortChange: (v: string) => void = () => {}

  aboutToAppear(): void {
    this.port = this.defaultPort
  }

  build() {
    Row() {
      Column({ space: '2vp' }) {
        Text(this.label)
          .fontSize('15fp')
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_on_light'))
        Text(this.desc)
          .fontSize('11fp')
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      TextInput({ text: this.port })
        .width('72vp')
        .height('32vp')
        .fontSize('13fp')
        .backgroundColor(Color.White)
        .borderRadius('8vp')
        .padding({ left: '8vp', right: '8vp' })
        .margin({ right: '10vp' })
        .onChange((v: string) => {
          this.port = v
          this.onPortChange(v)
        })

      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor($r('app.color.button_background'))
        .onChange((on: boolean) => { this.onToggle(on) })
        .width('44vp')
    }
    .width('100%')
    .padding('12vp')
    .backgroundColor($r('app.color.edit_text_background'))
    .borderRadius('12vp')
  }
}
