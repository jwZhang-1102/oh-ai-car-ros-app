/**
 * 遥控界面
 */
import router from '@ohos.router'
import { carApi } from '../CarUtill/CarApi'
import { CarEncode } from '../CarUtill/CarEncode'
import { CarBtnComponents } from '../components/CarBtnComponents'
import { CarRockerComponents } from '../components/CarRockerComponents'
import { VideoComponents } from '../components/VideoComponents'
import { VideoConfig } from '../utils/VideoConfig'
import { ButtonShadow, CardShadow } from '../styles/styles'

@Entry
@Component
struct RemoteControl {
  @State nowCtrlModel: CtrlModel = CtrlModel.Button
  ctrlTextTextList: string[] = ['按钮', '摇杆']
  ctrlModeList: CtrlModel[] = [CtrlModel.Button, CtrlModel.Rocker]

  aboutToAppear(): void {
    VideoConfig.syncFromPreferences()
  }

  build() {
    Row({ space: '16vp' }) {
      Column({ space: '10vp' }) {
        Row({ space: '10vp' }) {
          Button('返回')
            .fontSize('14fp')
            .fontColor($r('app.color.button_text'))
            .backgroundColor($r('app.color.button_background'))
            .shadow(ButtonShadow)
            .onClick(() => router.back())

          Column({ space: '2vp' }) {
            Text('单独控制')
              .fontSize('20fp')
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_on_light'))
            Text('实时视频 + 遥控驾驶')
              .fontSize('12fp')
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        Row({ space: '8vp' }) {
          ForEach(this.ctrlTextTextList, (item: string, index: number) => {
            MyTab({
              state: this.nowCtrlModel == this.ctrlModeList[index],
              text: item
            }).onClick(() => {
              this.nowCtrlModel = this.ctrlModeList[index]
            })
          }, (item: string) => item)
        }

        Stack() {
          CarBtnComponents()
            .visibility(
              this.nowCtrlModel == CtrlModel.Button ?
                Visibility.Visible :
                Visibility.None
            )

          CarRockerComponents()
            .width('100%')
            .height('100%')
            .visibility(
              this.nowCtrlModel == CtrlModel.Rocker ?
                Visibility.Visible :
                Visibility.None
            )
        }
        .width('100%')
        .layoutWeight(1)
        .constraintSize({ maxHeight: '200vp' })
        .padding('10vp')
        .backgroundColor($r('app.color.card_background'))
        .borderRadius('16vp')
        .border({ width: '1vp', color: $r('app.color.card_border') })
        .shadow(CardShadow)
      }
      .width(0)
      .layoutWeight(1)
      .height('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: '8vp' }) {
        Text('实时画面')
          .fontSize('13fp')
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        VideoComponents()
          .width('100%')

        Row() {
          Checkbox()
            .selectedColor($r('app.color.button_background'))
            .onChange((value: boolean) => {
              if (value) {
                carApi.send(CarEncode.TrackingOpenEncode())
              } else {
                carApi.send(CarEncode.TrackingCloseEncode())
              }
            })
          Text('自动循迹')
            .fontSize('14fp')
            .fontColor($r('app.color.text_on_light'))
            .margin({ left: '6vp' })
        }
        .width('100%')
        .padding({ left: '10vp', right: '10vp', top: '8vp', bottom: '8vp' })
        .backgroundColor($r('app.color.card_background'))
        .borderRadius('10vp')
        .border({ width: '1vp', color: $r('app.color.card_border') })
      }
      .width(0)
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .padding({
      left: '16vp',
      right: '16vp',
      top: '12vp',
      bottom: '12vp'
    })
    .backgroundColor($r('app.color.window_background'))
  }
}

enum CtrlModel {
  Button = 0,
  Rocker = 1,
}

@Component
struct MyTab {
  @Prop state: boolean = false
  @Prop text: string = 'hello'
  trueColor: string | Resource = $r('app.color.button_background')
  falseColor: string | Resource = $r('app.color.card_background')

  build() {
    Text(this.text)
      .fontSize('14fp')
      .fontColor(this.state ? $r('app.color.button_text') : $r('app.color.text_on_light'))
      .padding({ left: '16vp', right: '16vp', top: '6vp', bottom: '6vp' })
      .backgroundColor(this.state ? this.trueColor : this.falseColor)
      .borderRadius('16vp')
      .border({
        width: '1vp',
        color: this.state ? $r('app.color.button_background') : $r('app.color.card_border')
      })
  }
}
