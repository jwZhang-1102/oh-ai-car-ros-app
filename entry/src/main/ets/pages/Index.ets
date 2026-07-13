/**
 * 主页 - 竖屏极简风格
 */
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { PreferencesUtils } from '../utils/PreferencesUtils'
import { TCPClientManager } from '../tcp/TCPClientManager'
import { VideoComponents } from '../components/VideoComponents'

@Entry
@Component
struct Index {
  @State statusText: string = ''
  @State ip: string = '192.168.1.100'

  aboutToAppear(): void {
    this.loadConnectionStatus()
  }

  async loadConnectionStatus() {
    let net = PreferencesUtils.getInstance().netUtils
    if (!net) return
    let parts: string[] = []
    let ipAddr = await net.getIP() as string
    this.ip = ipAddr
    if (await net.getEnableTcp() as boolean) parts.push(`控车 ${await net.getTcpPort()}`)
    if (await net.getEnableVideo() as boolean) parts.push(`视频 ${await net.getVideoPort()}`)
    if (await net.getEnablePatrol() as boolean) parts.push(`巡检 ${await net.getPatrolPort()}`)
    if (parts.length > 0) {
      this.statusText = `已连接 · ${parts.join(' · ')}`
    } else {
      this.statusText = `${ipAddr} · 未选择端口`
    }
  }

  disconnectAndBack() {
    TCPClientManager.getInstance().closeConnection()
    VideoComponents.enabled = false
    promptAction.showToast({ message: '已断开连接' })
    router.replaceUrl({ url: 'pages/NetworkSettings' })
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('智检哨兵')
          .fontSize('18fp')
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_light'))
      }
      .width('100%')
      .height('56vp')
      .padding({ left: '16vp', right: '16vp' })
      .justifyContent(FlexAlign.Center)

      Scroll() {
        Column({ space: '16vp' }) {
          // 状态卡片
          Column({ space: '16vp' }) {
            Row() {
              Row({ space: '8vp' }) {
                Circle({ width: '10vp', height: '10vp' })
                  .fill('#22C55E')
                Text('已连接')
                  .fontSize('18fp')
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_on_light'))
              }

              Text(this.ip)
                .fontSize('13fp')
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            Button('断开连接')
              .width('100%')
              .height('44vp')
              .fontSize('14fp')
              .fontWeight(FontWeight.Medium)
              .fontColor('#EF4444')
              .backgroundColor('#FEF2F2')
              .borderRadius('12vp')
              .onClick(() => this.disconnectAndBack())
          }
          .padding('18vp')
          .backgroundColor($r('app.color.card_background'))
          .borderRadius('16vp')

          // 功能入口列表
          FeatureCard({
            icon: $r('app.media.tire'),
            title: '麦科朗姆',
            desc: '控制四个麦克纳姆轮',
            bgColor: '#DBEAFE',
            iconColor: '#2563EB',
            action: () => router.pushUrl({ url: 'pages/MecanumWheel' })
          })

          FeatureCard({
            icon: $r('app.media.vector'),
            title: '单独控制',
            desc: '遥控小车运动',
            bgColor: '#E0E7FF',
            iconColor: '#4F46E5',
            action: () => router.pushUrl({ url: 'pages/RemoteControl' })
          })

          FeatureCard({
            icon: $r('app.media.patrol'),
            title: '智能巡检',
            desc: 'AI 智能巡检检测',
            bgColor: '#D1FAE5',
            iconColor: '#059669',
            action: () => router.pushUrl({ url: 'pages/PatrolPage' })
          })
        }
        .width('100%')
        .padding({ left: '16vp', right: '16vp', bottom: '32vp' })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.window_background'))
  }
}

@Component
struct FeatureCard {
  @Prop icon: Resource = $r('app.media.vector')
  @Prop title: string = ''
  @Prop desc: string = ''
  @Prop bgColor: string = '#DBEAFE'
  @Prop iconColor: string = '#2563EB'
  action: () => void = () => {}

  build() {
    Row({ space: '14vp' }) {
      Stack() {
        Column()
          .width('48vp').height('48vp')
          .backgroundColor(this.bgColor)
          .borderRadius('12vp')
        Image(this.icon)
          .width('24vp').height('24vp')
          .fillColor(this.iconColor)
      }

      Column({ space: '4vp' }) {
        Text(this.title)
          .fontSize('16fp')
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_light'))
        Text(this.desc)
          .fontSize('12fp')
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›')
        .fontSize('22fp')
        .fontColor('#D1D5DB')
    }
    .width('100%')
    .padding('16vp')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius('16vp')
    .onClick(() => this.action())
  }
}
