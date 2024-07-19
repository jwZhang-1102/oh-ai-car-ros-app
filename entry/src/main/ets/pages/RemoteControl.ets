/**
 * 遥控界面
 */
@Entry
@Component
struct RemoteControl {
  @State message: string = 'Hello World';

  build() {
    Row() {
      Column() {
        // 操控按钮
        Grid() {
          GridItem()
          GridItem() {
            Button("前")// .backgroundColor(0xF9CF93)
              .width('100%')
              .height('100%')
          }

          GridItem()
          GridItem() {
            Button("左")
              .width('100%')
              .height('100%')
          }

          GridItem() {
            Button("后")
              .width('100%')
              .height('100%')
          }

          GridItem() {
            Button("右")
              .width('100%')
              .height('100%')
          }
        }
        .rowsTemplate('1fr 1fr')
        .columnsTemplate('1fr 1fr 1fr')
        //100
        // 10
        .width('320vp')
        .height('210vp')
      }

      .width(0)
      .layoutWeight(1)

      Column() {
      }
      .width(0)
      .layoutWeight(1)
    }
    .height('100%')
  }
}