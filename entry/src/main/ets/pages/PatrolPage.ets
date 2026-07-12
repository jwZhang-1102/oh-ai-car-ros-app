/**
 * 智能巡检 - 事件列表（Day2 + 自动刷新）
 */
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { PreferencesUtils } from '../utils/PreferencesUtils'
import { PatrolApi } from '../patrol/PatrolApi'
import { PatrolEvent } from '../patrol/PatrolEventModel'
import { ButtonShadow, CardShadow } from '../styles/styles'

const AUTO_REFRESH_MS = 4000

@Entry
@Component
struct PatrolPage {
  @State host: string = ''
  @State patrolPort: number = 6700
  @State events: PatrolEvent[] = []
  @State loading: boolean = false
  @State selected: PatrolEvent | null = null
  @State imageUrl: string = ''
  @State autoRefresh: boolean = true
  private refreshTimer: number = -1

  aboutToAppear(): void {
    this.loadHostAndRefresh()
    this.startAutoRefresh()
  }

  aboutToDisappear(): void {
    this.stopAutoRefresh()
  }

  startAutoRefresh() {
    this.stopAutoRefresh()
    if (!this.autoRefresh) {
      return
    }
    this.refreshTimer = setInterval(() => {
      this.refreshEvents(true)
    }, AUTO_REFRESH_MS)
  }

  stopAutoRefresh() {
    if (this.refreshTimer >= 0) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = -1
    }
  }

  async loadHostAndRefresh() {
    let net = PreferencesUtils.getInstance().netUtils
    if (net) {
      this.host = await net.getIP() as string
      let portStr = await net.getPatrolPort() as string
      this.patrolPort = Number.parseInt(portStr)
    }
    await this.refreshEvents(false)
  }

  async refreshEvents(silent: boolean = false) {
    if (!this.host) {
      if (!silent) {
        promptAction.showToast({ message: '未配置小车 IP' })
      }
      return
    }
    if (this.loading) {
      return
    }
    this.loading = true
    let prevCount = this.events.length
    this.events = await PatrolApi.fetchEvents(this.host, this.patrolPort)
    this.loading = false
    if (this.events.length === 0) {
      if (!silent) {
        promptAction.showToast({ message: '暂无事件或服务未启动' })
      }
      this.selected = null
      this.imageUrl = ''
      return
    }
    if (!silent && this.events.length > prevCount) {
      promptAction.showToast({ message: `新增 ${this.events.length - prevCount} 条事件` })
    }
    if (this.selected) {
      let stillExists = this.events.some((e) => e.id === this.selected?.id)
      if (!stillExists) {
        this.selectEvent(this.events[0])
      } else {
        this.imageUrl = PatrolApi.snapshotUrl(this.host, this.selected.snapshot, this.patrolPort)
      }
    } else {
      this.selectEvent(this.events[0])
    }
  }

  selectEvent(item: PatrolEvent) {
    this.selected = item
    this.imageUrl = PatrolApi.snapshotUrl(this.host, item.snapshot, this.patrolPort)
  }

  build() {
    Row({ space: '12vp' }) {
      Column({ space: '8vp' }) {
        Row({ space: '8vp' }) {
          Button('返回')
            .fontSize('14fp')
            .fontColor($r('app.color.button_text'))
            .backgroundColor($r('app.color.button_background'))
            .shadow(ButtonShadow)
            .onClick(() => router.back())

          Column({ space: '2vp' }) {
            Text('智能巡检')
              .fontSize('20fp')
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_on_light'))
            Text(this.host ? `${this.host}:${this.patrolPort} · 共 ${this.events.length} 条` : '未配置小车 IP')
              .fontSize('12fp')
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button(this.loading ? '…' : '刷新')
            .fontSize('14fp')
            .fontColor($r('app.color.button_text'))
            .backgroundColor($r('app.color.button_background'))
            .shadow(ButtonShadow)
            .enabled(!this.loading)
            .onClick(() => this.refreshEvents(false))
        }
        .width('100%')

        Row({ space: '6vp' }) {
          Toggle({ type: ToggleType.Switch, isOn: this.autoRefresh })
            .selectedColor($r('app.color.button_background'))
            .onChange((on: boolean) => {
              this.autoRefresh = on
              if (on) {
                this.startAutoRefresh()
              } else {
                this.stopAutoRefresh()
              }
            })
          Text(this.autoRefresh ? '自动刷新（4 秒）' : '已暂停自动刷新')
            .fontSize('12fp')
            .fontColor($r('app.color.text_secondary'))
        }

        if (this.events.length === 0 && !this.loading) {
          Column({ space: '8vp' }) {
            Text('暂无巡检事件')
              .fontSize('16fp')
              .fontColor($r('app.color.text_on_light'))
            Text('请运行 patrol_detector 与 patrol_server')
              .fontSize('12fp')
              .fontColor($r('app.color.text_muted'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: '8vp' }) {
            ForEach(this.events, (item: PatrolEvent) => {
              ListItem() {
                this.eventCard(item)
              }
            }, (item: PatrolEvent) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width(0)
      .layoutWeight(1)
      .height('100%')

      Column({ space: '6vp' }) {
        Text('事件截图')
          .fontSize('14fp')
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        if (this.imageUrl) {
          Image(this.imageUrl)
            .width('100%')
            .layoutWeight(1)
            .objectFit(ImageFit.Contain)
            .backgroundColor($r('app.color.surface_dark'))
            .borderRadius('10vp')
        } else {
          Column() {
            Text('点击左侧事件查看截图')
              .fontSize('14fp')
              .fontColor($r('app.color.text_muted'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius('10vp')
          .border({ width: '1vp', color: $r('app.color.card_border'), style: BorderStyle.Dashed })
        }

        if (this.selected) {
          Row({ space: '8vp' }) {
            Text(this.selected.className)
              .fontSize('15fp')
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_on_light'))
            Text(`${(this.selected.confidence * 100).toFixed(0)}%`)
              .fontSize('12fp')
              .fontColor($r('app.color.accent_dark'))
              .padding({ left: '8vp', right: '8vp', top: '2vp', bottom: '2vp' })
              .backgroundColor($r('app.color.chip_background'))
              .borderRadius('10vp')
          }
          Text(`${this.selected.time} · ${this.selected.id}`)
            .fontSize('11fp')
            .fontColor($r('app.color.text_muted'))
            .width('100%')
        }
      }
      .width(0)
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .padding({
      left: '14vp',
      right: '14vp',
      top: '10vp',
      bottom: '10vp'
    })
    .backgroundColor($r('app.color.window_background'))
  }

  @Builder
  eventCard(item: PatrolEvent) {
    Row({ space: '10vp' }) {
      Column({ space: '4vp' }) {
        Text(item.time)
          .fontSize('12fp')
          .fontColor($r('app.color.text_muted'))
        Text(item.className)
          .fontSize('16fp')
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_on_light'))
        Text(item.id)
          .fontSize('10fp')
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(`${(item.confidence * 100).toFixed(0)}%`)
        .fontSize('12fp')
        .fontColor($r('app.color.accent_dark'))
        .padding({ left: '8vp', right: '8vp', top: '3vp', bottom: '3vp' })
        .backgroundColor($r('app.color.chip_background'))
        .borderRadius('10vp')

      if (item.snapshot) {
        Image(PatrolApi.snapshotUrl(this.host, item.snapshot, this.patrolPort))
          .width('64vp')
          .height('48vp')
          .objectFit(ImageFit.Cover)
          .borderRadius('6vp')
      }
    }
    .width('100%')
    .padding('10vp')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius('12vp')
    .border({
      width: this.selected?.id === item.id ? '2vp' : '1vp',
      color: this.selected?.id === item.id ?
        $r('app.color.button_background') :
        $r('app.color.card_border')
    })
    .shadow(CardShadow)
    .onClick(() => this.selectEvent(item))
  }
}
