import router from '@ohos.router';

@Entry
@Component
struct Index {
  @State message: string = 'Hello World';

  build() {
    Column() {
      Scroll() {
        Row({ space: '5vp' }) {
          // this.newLocalBuilder
          Item({
            text: "麦科朗姆",
            event: () => {
              router.pushUrl({
                url: 'pages/MecanumWheel',
              })
            }
          })
            .width('300vp')
            .height('100%')

          Item({
            text: "单独控制",
            event: () => {
              router.pushUrl({ url: 'pages/RemoteControl', })
            }
          })
            .width('300vp')
            .height('100%')
        }
        .height('60%')
      }
      .scrollable(ScrollDirection.Horizontal) // 滚动方向纵向
      .height('100%')
    }.width('100%')
  }
}

@Component
struct Item {
  @State text: string = "";
  event: (event?: ClickEvent) => void = () => {
  }

  build() {
    // Column() {
    Button(this.text)// }
      .width('100%')
      .height('100%')
  // }
      // .alignItems(HorizontalAlign.Center)
      // .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.event()
      })
      // .border({ //边框类型
      //   radius: '10vp',
      //   color: Color.Gray,
      //   width: '1vp'
      // })

  }
}