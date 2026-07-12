/**
 * 网络设置界面
 */
import { TCPClientManager } from '../tcp/TCPClientManager'
import { TCPClientSendUtils } from '../tcp/TCPClientSendUtils'
import promptAction from '@ohos.promptAction'
import router from '@ohos.router'
import { PreferencesUtils } from '../utils/PreferencesUtils'
import { VideoComponents } from '../components/VideoComponents'
import { VideoConfig } from '../utils/VideoConfig'
import { ButtonShadow, CardShadow } from '../styles/styles'
import { MyUtils } from '../utils/MyUtils'
import { PageHeader } from '../components/PageHeader'
import { PatrolApi } from '../patrol/PatrolApi'

@Entry
@Component
struct NetworkSettings {
  build() {
    Column() {
      Scroll() {
        Column({ space: '20vp' }) {
          PageHeader({
            title: '连接小车',
            subtitle: '勾选要连接的端口，端口号可随时修改'
          })

          LoginComponent({
            connectSuccessRun: () => {
              router.replaceUrl({ url: 'pages/Index' })
            },
            connectfailRun: () => {
              if (MyUtils.isDebug) {
                router.replaceUrl({ url: 'pages/Index' })
              }
            }
          })
        }
        .width('440vp')
        .padding('28vp')
        .backgroundColor($r('app.color.card_background'))
        .borderRadius('24vp')
        .border({ width: '1vp', color: $r('app.color.card_border') })
        .shadow(CardShadow)
      }
      .scrollBar(BarState.Auto)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.window_background'))
  }
}

@Component
struct LoginComponent {
  LabelWidth: Length = '88vp'
  FontSize: Length = '16fp'
  @State ip: string = '10.147.13.194'
  @State tcpPort: string = '6000'
  @State videoPort: string = '6500'
  @State patrolPort: string = '6700'
  @State enableTcp: boolean = true
  @State enableVideo: boolean = false
  @State enablePatrol: boolean = true
  @State connecting: boolean = false
  connectSuccessRun = () => {
  }
  connectfailRun = () => {
  }

  aboutToAppear(): void {
    this.readNetConfig()
  }

  build() {
    Column({ space: '12vp' }) {
      this.ipRow()

      Row({ space: '10vp' }) {
        Checkbox()
          .select(this.enableTcp)
          .selectedColor($r('app.color.button_background'))
          .onChange((on: boolean) => { this.enableTcp = on })
        Text('控车 TCP')
          .width(this.LabelWidth)
          .fontSize(this.FontSize)
          .fontColor($r('app.color.text_on_light'))
          .fontWeight(FontWeight.Medium)
        TextInput({ text: this.tcpPort, placeholder: '6000' })
          .onChange((v: string) => { this.tcpPort = v })
          .layoutWeight(1)
          .height('44vp')
          .fontSize('16fp')
          .fontColor($r('app.color.text_on_light'))
          .backgroundColor($r('app.color.edit_text_background'))
          .borderRadius('10vp')
          .padding({ left: '12vp', right: '12vp' })
      }
      .width('100%')
      .opacity(this.enableTcp ? 1 : 0.55)

      Row({ space: '10vp' }) {
        Checkbox()
          .select(this.enableVideo)
          .selectedColor($r('app.color.button_background'))
          .onChange((on: boolean) => { this.enableVideo = on })
        Text('视频')
          .width(this.LabelWidth)
          .fontSize(this.FontSize)
          .fontColor($r('app.color.text_on_light'))
          .fontWeight(FontWeight.Medium)
        TextInput({ text: this.videoPort, placeholder: '6500' })
          .onChange((v: string) => { this.videoPort = v })
          .layoutWeight(1)
          .height('44vp')
          .fontSize('16fp')
          .fontColor($r('app.color.text_on_light'))
          .backgroundColor($r('app.color.edit_text_background'))
          .borderRadius('10vp')
          .padding({ left: '12vp', right: '12vp' })
      }
      .width('100%')
      .opacity(this.enableVideo ? 1 : 0.55)

      Row({ space: '10vp' }) {
        Checkbox()
          .select(this.enablePatrol)
          .selectedColor($r('app.color.button_background'))
          .onChange((on: boolean) => { this.enablePatrol = on })
        Text('巡检 HTTP')
          .width(this.LabelWidth)
          .fontSize(this.FontSize)
          .fontColor($r('app.color.text_on_light'))
          .fontWeight(FontWeight.Medium)
        TextInput({ text: this.patrolPort, placeholder: '6700' })
          .onChange((v: string) => { this.patrolPort = v })
          .layoutWeight(1)
          .height('44vp')
          .fontSize('16fp')
          .fontColor($r('app.color.text_on_light'))
          .backgroundColor($r('app.color.edit_text_background'))
          .borderRadius('10vp')
          .padding({ left: '12vp', right: '12vp' })
      }
      .width('100%')
      .opacity(this.enablePatrol ? 1 : 0.55)

      Text('提示：视频(6500)与 YOLO 巡检共用摄像头，建议二选一勾选')
        .fontSize('11fp')
        .fontColor($r('app.color.text_muted'))
        .width('100%')

      Button(this.connecting ? '连接中…' : '连接小车')
        .width('100%')
        .height('48vp')
        .fontSize('18fp')
        .fontColor($r('app.color.button_text'))
        .backgroundColor($r('app.color.button_background'))
        .shadow(ButtonShadow)
        .borderRadius('12vp')
        .enabled(!this.connecting && this.hasAnyEnabled())
        .onClick(() => this.connectSelected())
    }
    .width('100%')
  }

  hasAnyEnabled(): boolean {
    return this.enableTcp || this.enableVideo || this.enablePatrol
  }

  @Builder
  ipRow() {
    Row({ space: '10vp' }) {
      Text('IP')
        .width(this.LabelWidth)
        .fontSize(this.FontSize)
        .fontColor($r('app.color.text_on_light'))
        .fontWeight(FontWeight.Medium)
      TextInput({ text: this.ip, placeholder: '10.147.13.194' })
        .onChange((v: string) => { this.ip = v })
        .layoutWeight(1)
        .height('44vp')
        .fontSize('16fp')
        .fontColor($r('app.color.text_on_light'))
        .backgroundColor($r('app.color.edit_text_background'))
        .borderRadius('10vp')
        .padding({ left: '12vp', right: '12vp' })
    }
    .width('100%')
  }

  private async connectSelected() {
    if (!this.hasAnyEnabled()) {
      promptAction.showToast({ message: '请至少勾选一个端口' })
      return
    }
    if (this.enableVideo && this.enablePatrol) {
      promptAction.showToast({ message: '视频与巡检建议不要同时勾选' })
    }
    this.connecting = true
    await this.saveNetConfig()
    this.applyVideoConfig()

    let okList: string[] = []
    let failList: string[] = []

    if (this.enableTcp) {
      if (this.tcpPort.trim().length === 0) {
        failList.push('控车(未填端口)')
      } else {
        let tcpOk = await this.tryTcpConnect()
        if (tcpOk) {
          okList.push(`控车:${this.tcpPort}`)
        } else {
          failList.push(`控车:${this.tcpPort}`)
        }
      }
    }

    if (this.enableVideo) {
      if (this.videoPort.trim().length === 0) {
        failList.push('视频(未填端口)')
      } else {
        VideoConfig.applyFromForm(this.ip, this.videoPort, true)
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
        if (patrolOk) {
          okList.push(`巡检:${this.patrolPort}`)
        } else {
          failList.push(`巡检:${this.patrolPort}`)
        }
      }
    }

    this.connecting = false

    if (okList.length > 0) {
      promptAction.showToast({ message: `已连接 ${okList.join(' ')}` })
      this.connectSuccessRun()
    } else if (failList.length > 0) {
      promptAction.showToast({ message: `连接失败: ${failList.join(' ')}` })
      this.connectfailRun()
    }
  }

  private applyVideoConfig() {
    VideoConfig.applyFromForm(this.ip, this.videoPort, this.enableVideo)
  }

  private async tryTcpConnect(): Promise<boolean> {
    TCPClientManager.getInstance().initNetAddress({
      address: this.ip,
      port: Number.parseInt(this.tcpPort)
    })
    let isConnect = await TCPClientManager.getInstance().connect()
    if (isConnect) {
      TCPClientSendUtils.getInstance().init()
    }
    return isConnect
  }

  private readNetConfig() {
    const netUtils = PreferencesUtils.getInstance().netUtils
    if (!netUtils) {
      return
    }
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
    if (!netUtils) {
      return
    }
    netUtils.setIp(this.ip)
    netUtils.setTcpPort(this.tcpPort)
    netUtils.setVideoPort(this.videoPort)
    netUtils.setPatrolPort(this.patrolPort)
    netUtils.setEnableTcp(this.enableTcp)
    netUtils.setEnableVideo(this.enableVideo)
    netUtils.setEnablePatrol(this.enablePatrol)
  }
}
