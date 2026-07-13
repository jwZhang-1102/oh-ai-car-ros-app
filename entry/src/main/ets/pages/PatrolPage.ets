/**
 * 智能巡检 - 竖屏极简风格
 */
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { PreferencesUtils } from '../utils/PreferencesUtils'
import { PatrolApi } from '../patrol/PatrolApi'
import { PatrolEvent } from '../patrol/PatrolEventModel'

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
  @State showModal: boolean = false
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
    if (!this.autoRefresh) return
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
      if (!silent) promptAction.showToast({ message: '未配置小车 IP' })
      return
    }
    if (this.loading) return
    this.loading = true
    let prevCount = this.events.length
    this.events = await PatrolApi.fetchEvents(this.host, this.patrolPort)
    this.loading = false
    if (this.events.length === 0) {
      if (!silent) promptAction.showToast({ message: '暂无事件或服务未启动' })
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
      }
    } else {
      this.selectEvent(this.events[0])
    }
  }

  selectEvent(item: PatrolEvent) {
    this.selected = item
    this.imageUrl = PatrolApi.snapshotUrl(this.host, item.snapshot, this.patrolPort)
    this.showModal = true
  }

  build() {
    Stack() {
      Column() {
        // 顶栏
        Row() {
          Button({ type: ButtonType.Circle }) {
            Text('‹').fontSize('28fp').fontColor('#6B7280')
          }
          .width('36vp').height('36vp')
          .backgroundColor('#00000000')
          .onClick(() => router.back())

          Text('智能巡检')
            .fontSize('18fp')
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_light'))
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Blank().width('36vp')
        }
        .width('100%')
        .height('56vp')
        .padding({ left: '14vp', right: '14vp' })

        Scroll() {
          Column({ space: '14vp' }) {
            // 连接状态卡片
            Row() {
              Column({ space: '4vp' }) {
                Row({ space: '6vp' }) {
                  Circle({ width: '8vp', height: '8vp' }).fill('#22C55E')
                  Text(`${this.host}:${this.patrolPort}`)
                    .fontSize('14fp')
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.text_on_light'))
                }
                Text('巡检服务运行中')
                  .fontSize('11fp')
                  .fontColor($r('app.color.text_secondary'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Button() {
                Text('刷新').fontSize('12fp')
              }
              .fontColor($r('app.color.button_background'))
              .backgroundColor('#DBEAFE')
              .borderRadius('8vp')
              .height('32vp')
              .enabled(!this.loading)
              .onClick(() => this.refreshEvents(false))
            }
            .width('100%')
            .padding('14vp')
            .backgroundColor($r('app.color.card_background'))
            .borderRadius('16vp')

            // 自动刷新开关
            Row() {
              Text('YOLO 检测事件')
                .fontSize('12fp')
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_secondary'))

              Blank()

              Text('自动刷新')
                .fontSize('11fp')
                .fontColor($r('app.color.text_muted'))
                .margin({ right: '6vp' })

              Toggle({ type: ToggleType.Switch, isOn: this.autoRefresh })
                .selectedColor($r('app.color.button_background'))
                .onChange((on: boolean) => {
                  this.autoRefresh = on
                  if (on) this.startAutoRefresh()
                  else this.stopAutoRefresh()
                })
                .width('40vp')
            }
            .width('100%')
            .padding({ left: '4vp', right: '4vp' })

            // 事件列表
            if (this.events.length === 0 && !this.loading) {
              Column({ space: '10vp' }) {
                Text('📭')
                  .fontSize('40fp')
                Text('暂无检测事件')
                  .fontSize('14fp')
                  .fontColor($r('app.color.text_muted'))
              }
              .width('100%')
              .height('200vp')
              .justifyContent(FlexAlign.Center)
            } else {
              List({ space: '10vp' }) {
                ForEach(this.events, (item: PatrolEvent) => {
                  ListItem() {
                    this.eventCard(item)
                  }
                }, (item: PatrolEvent) => item.id)
              }
              .width('100%')
              .scrollBar(BarState.Auto)
            }
          }
          .width('100%')
          .padding({ left: '16vp', right: '16vp', bottom: '32vp' })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.window_background'))

      // 详情弹窗
      if (this.showModal && this.selected) {
        Column() {
          Column()
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('#99000000')
            .onClick(() => { this.showModal = false })

          Column({ space: '14vp' }) {
            Row() {
              Text('检测详情')
                .fontSize('16fp')
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_on_light'))
              Blank()
              Text('✕')
                .fontSize('20fp')
                .fontColor($r('app.color.text_secondary'))
                .onClick(() => { this.showModal = false })
            }
            .width('100%')

            if (this.imageUrl) {
              Image(this.imageUrl)
                .width('100%')
                .aspectRatio(1)
                .objectFit(ImageFit.Cover)
                .backgroundColor('#F3F4F6')
                .borderRadius('16vp')
            }

            Column({ space: '10vp' }) {
              Row({ space: '10vp' }) {
                Column({ space: '4vp' }) {
                  Text('类别')
                    .fontSize('10fp')
                    .fontColor($r('app.color.text_muted'))
                  Text(this.selected.className)
                    .fontSize('15fp')
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.button_background'))
                }
                .padding('12vp')
                .backgroundColor('#F3F4F6')
                .borderRadius('12vp')
                .layoutWeight(1)

                Column({ space: '4vp' }) {
                  Text('置信度')
                    .fontSize('10fp')
                    .fontColor($r('app.color.text_muted'))
                  Text(`${(this.selected.confidence * 100).toFixed(1)}%`)
                    .fontSize('15fp')
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#22C55E')
                }
                .padding('12vp')
                .backgroundColor('#F3F4F6')
                .borderRadius('12vp')
                .layoutWeight(1)
              }

              Column({ space: '4vp' }) {
                Text('检测时间')
                  .fontSize('10fp')
                  .fontColor($r('app.color.text_muted'))
                Text(`${this.selected.time}`)
                  .fontSize('14fp')
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_on_light'))
              }
              .width('100%')
              .padding('12vp')
              .backgroundColor('#F3F4F6')
              .borderRadius('12vp')
            }

            Button('返回列表')
              .width('100%')
              .height('48vp')
              .fontSize('15fp')
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.button_background'))
              .borderRadius('12vp')
              .onClick(() => { this.showModal = false })
          }
          .padding('18vp')
          .backgroundColor(Color.White)
          .borderRadius({ topLeft: '24vp', topRight: '24vp' })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  eventCard(item: PatrolEvent) {
    Row({ space: '12vp' }) {
      Image(PatrolApi.snapshotUrl(this.host, item.snapshot, this.patrolPort))
        .width('64vp').height('64vp')
        .objectFit(ImageFit.Cover)
        .borderRadius('12vp')
        .backgroundColor('#F3F4F6')

      Column({ space: '6vp' }) {
        Row() {
          Text(item.className)
            .fontSize('14fp')
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_light'))
          Blank()
          Text(item.time)
            .fontSize('10fp')
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')

        Row({ space: '8vp' }) {
          Column()
            .layoutWeight(1)
            .height('4vp')
            .backgroundColor('#F3F4F6')
            .borderRadius('2vp')
          Column()
            .width(`${item.confidence * 100}%`)
            .height('4vp')
            .backgroundColor(
              item.confidence > 0.9 ? '#22C55E' :
              item.confidence > 0.7 ? '#2563EB' : '#F59E0B'
            )
            .borderRadius('2vp')
        }
        .width('50%')

        Row() {
          Text(`${(item.confidence * 100).toFixed(1)}%`)
            .fontSize('11fp')
            .fontWeight(FontWeight.Bold)
            .fontColor(
              item.confidence > 0.9 ? '#16A34A' :
              item.confidence > 0.7 ? '#2563EB' : '#D97706'
            )
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding('12vp')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius('14vp')
    .onClick(() => this.selectEvent(item))
  }
}
