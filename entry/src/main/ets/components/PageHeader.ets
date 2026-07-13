/**
 * 通用标题栏 - 极简风格
 */
@Component
export struct PageHeader {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop showBack: boolean = false
  onBack: () => void = () => {}

  build() {
    Row({ space: '12vp' }) {
      if (this.showBack) {
        Button({ type: ButtonType.Circle }) {
          Text('‹').fontSize('28fp').fontColor('#6B7280')
        }
        .width('36vp').height('36vp')
        .backgroundColor('#00000000')
        .onClick(() => this.onBack())
      }

      Column({ space: '4vp' }) {
        Text(this.title)
          .fontSize('18fp')
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_light'))
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize('12fp')
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
