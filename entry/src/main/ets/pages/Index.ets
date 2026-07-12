import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { ButtonShadow, CardShadow } from '../styles/styles'
import { PageHeader } from '../components/PageHeader'
import { PreferencesUtils } from '../utils/PreferencesUtils'
import { TCPClientManager } from '../tcp/TCPClientManager'
import { VideoComponents } from '../components/VideoComponents'

@Entry
@Component
struct Index {
  @State statusText: string = ''

  aboutToAppear(): void {
    this.loadConnectionStatus()
  }

  async loadConnectionStatus() {
    let net = PreferencesUtils.getInstance().netUtils
    if (!net) {
      return
    }
    let parts: string[] = []
    let ip = await net.getIP() as string
    if (await net.getEnableTcp() as boolean) {
      parts.push(`控车 ${await net.getTcpPort()}`)
    }
    if (await net.getEnableVideo() as boolean) {
      parts.push(`视频 ${await net.getVideoPort()}`)
    }
    if (await net.getEnablePatrol() as boolean) {
      parts.push(`巡检 ${await net.getPatrolPort()}`)
    }
    if (parts.length > 0) {
      this.statusText = `${ip} · ${parts.join(' · ')}`
    } else {
      this.statusText = `${ip} · 未选择端口`
    }
  }

  disconnectAndBack() {
    TCPClientManager.getInstance().closeConnection()
    VideoComponents.enabled = false
    promptAction.showToast({ message: '已断开连接' })
    router.replaceUrl({ url: 'pages/NetworkSettings' })
  }

  build() {
    Column({ space: '16vp' }) {
      Row({ space: '12vp' }) {
        Column({ space: '4vp' }) {
          PageHeader({
            title: '智检哨兵',
            subtitle: this.statusText.length > 0 ? this.statusText : '智慧小车遥控 · 巡检 · 留痕'
          })
        }
        .layoutWeight(1)

        Button('断开连接')
          .fontSize('14fp')
          .fontColor($r('app.color.button_text'))
          .backgroundColor($r('app.color.button_background'))
          .shadow(ButtonShadow)
          .onClick(() => this.disconnectAndBack())
      }
      .width('100%')
      .padding({ left: '24vp', right: '24vp', top: '20vp' })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Row({ space: '24vp' }) {
          ItemButton({
            text: '麦科朗姆',
            desc: '四轮独立调速',
            icon: $r('app.media.tire'),
            event: () => {
              router.pushUrl({ url: 'pages/MecanumWheel' })
            }
          })
            .width('280vp')
            .height('100%')

          ItemButton({
            text: '单独控制',
            desc: '按钮 / 摇杆遥控',
            icon: $r('app.media.vector'),
            event: () => {
              router.pushUrl({ url: 'pages/RemoteControl' })
            }
          })
            .width('280vp')
            .height('100%')

          ItemButton({
            text: '智能巡检',
            desc: 'YOLO 事件与截图',
            icon: $r('app.media.patrol'),
            event: () => {
              router.pushUrl({ url: 'pages/PatrolPage' })
            }
          })
            .width('280vp')
            .height('100%')
        }
        .padding({ left: '24vp', right: '24vp', bottom: '8vp' })
        .height('100%')
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)

      Text('左右滑动查看更多功能')
        .fontSize('13fp')
        .fontColor($r('app.color.text_muted'))
        .margin({ bottom: '16vp' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.window_background'))
  }
}

@Component
struct ItemButton {
  @Prop text: string = ''
  @Prop desc: string = ''
  @Prop icon: Resource = $r('app.media.vector')
  event: (event?: ClickEvent) => void = () => {
  }

  build() {
    Column({ space: '16vp' }) {
      Stack() {
        Column()
          .width('120vp')
          .height('120vp')
          .borderRadius('60vp')
          .backgroundColor('#33FFFFFF')

        Image(this.icon)
          .width('96vp')
          .height('96vp')
      }

      Column({ space: '6vp' }) {
        Text(this.text)
          .fontColor($r('app.color.text_on_light'))
          .fontSize($r('app.float.index_text_size'))
          .fontWeight(FontWeight.Medium)
        Text(this.desc)
          .fontSize('13fp')
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding('24vp')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius($r('app.float.index_button_radius'))
    .border({ width: '1vp', color: $r('app.color.card_border') })
    .shadow(CardShadow)
    .onClick(() => this.event())
  }
}
