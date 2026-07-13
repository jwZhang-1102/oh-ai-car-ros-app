/**
 * 遥控界面 - 竖屏极简风格
 */
import router from '@ohos.router'
import { carApi } from '../CarUtill/CarApi'
import { CarEncode } from '../CarUtill/CarEncode'
import { CarBtnComponents } from '../components/CarBtnComponents'
import { CarRockerComponents } from '../components/CarRockerComponents'
import { VideoComponents } from '../components/VideoComponents'
import { VideoConfig } from '../utils/VideoConfig'

@Entry
@Component
struct RemoteControl {
  @State nowCtrlModel: CtrlModel = CtrlModel.Button

  aboutToAppear(): void {
    VideoConfig.syncFromPreferences()
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('‹').fontSize('28fp').fontColor('#6B7280')
        }
        .width('36vp').height('36vp')
        .backgroundColor('#00000000')
        .onClick(() => router.back())

        Text('单独控制')
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
        Column({ space: '16vp' }) {
          // 视频区域
          Stack() {
            VideoComponents()
              .width('100%')
              .height('200vp')
          }
          .width('100%')
          .height('200vp')
          .borderRadius('16vp')
          .clip(true)

          // 模式切换 pill
          Row() {
            Text('按钮模式')
              .fontSize('13fp')
              .fontWeight(FontWeight.Medium)
              .fontColor(this.nowCtrlModel == CtrlModel.Button ?
                $r('app.color.button_background') : $r('app.color.text_secondary'))
              .padding({ left: '20vp', right: '20vp', top: '10vp', bottom: '10vp' })
              .backgroundColor(this.nowCtrlModel == CtrlModel.Button ?
                Color.White : '#00000000')
              .borderRadius('10vp')
              .onClick(() => { this.nowCtrlModel = CtrlModel.Button })

            Text('摇杆模式')
              .fontSize('13fp')
              .fontWeight(FontWeight.Medium)
              .fontColor(this.nowCtrlModel == CtrlModel.Rocker ?
                $r('app.color.button_background') : $r('app.color.text_secondary'))
              .padding({ left: '20vp', right: '20vp', top: '10vp', bottom: '10vp' })
              .backgroundColor(this.nowCtrlModel == CtrlModel.Rocker ?
                Color.White : '#00000000')
              .borderRadius('10vp')
              .onClick(() => { this.nowCtrlModel = CtrlModel.Rocker })
          }
          .padding('3vp')
          .backgroundColor($r('app.color.edit_text_background'))
          .borderRadius('12vp')

          // 控制区
          Stack() {
            CarBtnComponents()
              .visibility(
                this.nowCtrlModel == CtrlModel.Button ?
                  Visibility.Visible : Visibility.None
              )

            Column() {
              CarRockerComponents()
                .width('200vp')
                .height('200vp')
              Text('滑动摇杆控制运动')
                .fontSize('11fp')
                .fontColor($r('app.color.text_muted'))
                .margin({ top: '12vp' })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .visibility(
              this.nowCtrlModel == CtrlModel.Rocker ?
                Visibility.Visible : Visibility.None
            )
          }
          .width('100%')

          // 自动循迹开关
          Row() {
            Text('自动循迹')
              .fontSize('15fp')
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_on_light'))
              .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: false })
              .selectedColor($r('app.color.button_background'))
              .onChange((value: boolean) => {
                if (value) {
                  carApi.send(CarEncode.TrackingOpenEncode())
                } else {
                  carApi.send(CarEncode.TrackingCloseEncode())
                }
              })
          }
          .width('100%')
          .padding('14vp')
          .backgroundColor($r('app.color.card_background'))
          .borderRadius('16vp')
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

enum CtrlModel {
  Button = 0,
  Rocker = 1,
}
