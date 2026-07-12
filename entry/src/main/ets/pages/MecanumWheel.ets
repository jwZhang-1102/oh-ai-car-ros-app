/**
 * 麦克纳姆轮单独控制界面
 */
import router from '@ohos.router'
import { carApi } from '../CarUtill/CarApi'
import { CarEncode } from '../CarUtill/CarEncode'
import { CarRockerComponents } from '../components/CarRockerComponents'
import { ButtonShadow, CardShadow } from '../styles/styles'
import { PageHeader } from '../components/PageHeader'

const TAG = 'SmartCarMecanumWheel'

@Entry
@Component
struct MecanumWheel {
  /**左前轮*/
  @State L1Value: number = 0
  /**左后轮*/
  @State L2Value: number = 0
  /**前后轮*/
  @State R1Value: number = 0
  /**右后轮*/
  @State R2Value: number = 0

  build() {
    Column({ space: '12vp' }) {
      PageHeader({
        title: '麦科朗姆',
        subtitle: '四轮独立调速 + 摇杆辅助',
        showBack: true,
        onBack: () => router.back()
      })
        .padding({ left: '20vp', right: '20vp', top: '16vp' })

      Row({ space: '16vp' }) {
      // 左侧一条
      Column() {
        // 前后轮单独控制
        Column() {
          // 左前轮
          SliderComponent({
            value: $L1Value
          })
          // 左后轮
          SliderComponent({
            value: $L2Value
          })


        }
        .width('100%')
        .height(0)
        .padding({ left: '30vp', right: '30vp' })
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)

        // 遥杆
        Column() {
          CarRockerComponents()
            .width('150vp')
            .height('150vp')
        }
        .width('100%')
        .height(0)
        .layoutWeight(1)
      }
      .height('100%')
      .width(0)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding('16vp')
      .backgroundColor($r('app.color.card_background'))
      .borderRadius('16vp')
      .border({ width: '1vp', color: $r('app.color.card_border') })
      .shadow(CardShadow)

      // 右侧一条
      Column() {
        // 前后轮单独控制
        Column() {
          // 右前轮
          SliderComponent({
            value: $R1Value
          })
          // 右后轮
          SliderComponent({
            value: $R2Value
          })
        }
        .height(0)
        .width('100%')
        .padding({ left: '30vp', right: '30vp' })
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

        Row({ space: '12vp' }) {
          Button('更新速度')
            .onClick(() => {
              this.sendSpeed()
            })
            .fontSize($r('app.float.float_1'))
            .fontColor($r('app.color.button_text'))
            .backgroundColor($r('app.color.button_background'))
            .shadow(ButtonShadow)

          Button('全部归零')
            .onClick(() => {
              this.L1Value = 0
              this.L2Value = 0
              this.R1Value = 0
              this.R2Value = 0
              this.sendSpeed()
            })
            .fontSize($r('app.float.float_1'))
            .fontColor($r('app.color.button_text'))
            .backgroundColor($r('app.color.button_background'))
            .shadow(ButtonShadow)
        }
        .height(0)
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      .height('100%')
      .width(0)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding('16vp')
      .backgroundColor($r('app.color.card_background'))
      .borderRadius('16vp')
      .border({ width: '1vp', color: $r('app.color.card_border') })
      .shadow(CardShadow)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: '20vp', right: '20vp', bottom: '20vp' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.window_background'))
  }

  /**
   * 发送数据到真实的车辆
   */
  sendSpeed() {
    console.log(TAG, 'speed', `l1`, this.L1Value, 'l2', this.L2Value)
    console.log(TAG, 'speed', `l1`, this.L1Value, 'l2', this.L2Value)
    //发送速度数据
    carApi.send(CarEncode.UpSpeedCarEncode(this.L1Value, this.L2Value, this.R1Value, this.R2Value));
  }
}

/**
 * 拖动状态条组件
 */
@Component
struct SliderComponent {
  @Link value: number;

  build() {
    Row() {
      // 左前轮
      Slider({
        value: this.value,
        min: -100,
        max: 100,
        style: SliderStyle.InSet
      })
        .blockColor($r('app.color.track_select_background'))
          .trackColor($r('app.color.track_background'))
          .selectedColor($r("app.color.slider_selected"))
          // .showTips(true)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.value = value
          console.info('value:' + value + 'mode:' + mode.toString())
        })
      Text(
        `${this.value.toFixed(0)}`
      )
        .width('30vp')
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.text_on_light'))
        .fontSize($r('app.float.float_1'))


    }
  }
}