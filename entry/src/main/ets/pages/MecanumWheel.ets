/**
 * 麦克纳姆轮单独控制 - 竖屏极简风格
 */
import router from '@ohos.router'
import { carApi } from '../CarUtill/CarApi'
import { CarEncode } from '../CarUtill/CarEncode'
import { CarRockerComponents } from '../components/CarRockerComponents'

const TAG = 'SmartCarMecanumWheel'

@Entry
@Component
struct MecanumWheel {
  @State L1Value: number = 0
  @State L2Value: number = 0
  @State R1Value: number = 0
  @State R2Value: number = 0

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

        Text('麦科朗姆')
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
          // 四轮滑块 2×2
          Column({ space: '12vp' }) {
            Row({ space: '12vp' }) {
              WheelSlider({
                label: 'FL 左前',
                value: $L1Value,
                borderLeft: true,
                sideColor: '#2563EB'
              })
                .layoutWeight(1)
              WheelSlider({
                label: 'FR 右前',
                value: $R1Value,
                borderLeft: false,
                sideColor: '#2563EB'
              })
                .layoutWeight(1)
            }

            Row({ space: '12vp' }) {
              WheelSlider({
                label: 'RL 左后',
                value: $L2Value,
                borderLeft: true,
                sideColor: '#9CA3AF'
              })
                .layoutWeight(1)
              WheelSlider({
                label: 'RR 右后',
                value: $R2Value,
                borderLeft: false,
                sideColor: '#9CA3AF'
              })
                .layoutWeight(1)
            }
          }

          // 摇杆辅助
          Column() {
            CarRockerComponents()
              .width('180vp')
              .height('180vp')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // 操作按钮
          Row({ space: '12vp' }) {
            Button('更新速度')
              .layoutWeight(1)
              .height('48vp')
              .fontSize('15fp')
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.button_background'))
              .borderRadius('12vp')
              .onClick(() => this.sendSpeed())

            Button('全部归零')
              .layoutWeight(1)
              .height('48vp')
              .fontSize('15fp')
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_on_light'))
              .backgroundColor($r('app.color.edit_text_background'))
              .borderRadius('12vp')
              .onClick(() => {
                this.L1Value = 0
                this.L2Value = 0
                this.R1Value = 0
                this.R2Value = 0
                this.sendSpeed()
              })
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
  }

  sendSpeed() {
    console.log(TAG, 'speed', `l1`, this.L1Value, 'l2', this.L2Value)
    carApi.send(CarEncode.UpSpeedCarEncode(this.L1Value, this.L2Value, this.R1Value, this.R2Value))
  }
}

@Component
struct WheelSlider {
  @Prop label: string = ''
  @Link value: number
  @Prop borderLeft: boolean = true
  @Prop sideColor: string = '#2563EB'

  build() {
    Column({ space: '10vp' }) {
      Row() {
        Text(this.label)
          .fontSize('11fp')
          .fontWeight(FontWeight.Bold)
          .fontColor('#9CA3AF')
        Text(`${this.value.toFixed(0)}`)
          .fontSize('14fp')
          .fontWeight(FontWeight.Bold)
          .fontColor('#2563EB')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Slider({
        value: this.value,
        min: -100,
        max: 100,
        style: SliderStyle.OutSet
      })
        .blockColor('#2563EB')
        .trackColor('#E5E7EB')
        .selectedColor('#2563EB')
        .onChange((value: number) => {
          this.value = value
        })
    }
    .padding('14vp')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius('16vp')
    .border({
      width: '4vp',
      color: this.sideColor
    })
    .borderWidth(this.borderLeft ?
      { left: '4vp', top: '0vp', right: '0vp', bottom: '0vp' } :
      { left: '0vp', top: '0vp', right: '4vp', bottom: '0vp' })
  }
}
