/**
 * 麦克纳姆轮单独控制界面
 */
const TAG = 'SmartCarMecanumWheel'

@Entry
@Component
struct MecanumWheel {
  @State message: string = 'Hello World';
  /**左前轮*/
  @State L1Value: number = 0;
  /**左后轮*/
  @State L2Value: number = 0;
  /**前后轮*/
  @State R1Value: number = 0;
  /**右后轮*/
  @State R2Value: number = 0;

  build() {

    Column() {
      Row() {
        // 左侧一条
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
        .height('100%')
        .width(0)
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .myBroderStyles()

        // 右侧一条
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
        .height('100%')
        .width(0)
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .myBroderStyles()

      }
      .layoutWeight(1)
      .height(0)

      Row() {
        Button('更新速度')
          .onClick(() => {
            this.sendSpeed();
          })
          .fontSize($r('app.float.float_1'))
        Button('全部归零')
          .onClick(() => {
            this.L1Value = 0
            this.L2Value = 0
            this.R1Value = 0
            this.R2Value = 0
          })
          .fontSize($r('app.float.float_1'))
      }
      .width('100%')
      .layoutWeight(1)
      .height(0)
      .myBroderStyles()
      .justifyContent(FlexAlign.Center)
    }
    .padding({
      left: '10vp',
      right: '10vp',
      top: '30vp',
      bottom: '30vp'
    })
  }

  /**边框样式*/
  @Styles
  myBroderStyles() {
    .border({
      radius: '10vp',
      color: Color.Gray,
      width: '1vp'
    })
  }

  /**
   * 发送数据到真实的车辆
   */
  sendSpeed() {
    console.log(TAG, 'speed', `l1`, this.L1Value, 'l2', this.L2Value)
    console.log(TAG, 'speed', `l1`, this.L1Value, 'l2', this.L2Value)

  }
}

/**
 * 拖动状态条组件
 */
@Component
struct SliderComponent {
  @Link value: number;

  build() {
    Column() {
      // 左前轮
      Slider({
        value: 0,
        min: -100,
        max: 100,
        style: SliderStyle.InSet
      })
        .blockColor('#191970')
        .trackColor('#ADD8E6')
        .selectedColor('#4169E1')// .showTips(true)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.value = value
          console.info('value:' + value + 'mode:' + mode.toString())
        })
      Text(
        `${this.value.toFixed(0)}`
      )
        .fontSize($r('app.float.float_1'))


    }
  }
}