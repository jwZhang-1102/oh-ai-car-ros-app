import { ButtonShadow } from '../styles/styles'

@Component
export struct PageHeader {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop showBack: boolean = false
  onBack: () => void = () => {
  }

  build() {
    Row({ space: '12vp' }) {
      if (this.showBack) {
        Button('返回')
          .fontSize('15fp')
          .fontColor($r('app.color.button_text'))
          .backgroundColor($r('app.color.button_background'))
          .shadow(ButtonShadow)
          .onClick(() => this.onBack())
      }

      Column({ space: '4vp' }) {
        Text(this.title)
          .fontSize('26fp')
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_light'))
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize('14fp')
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
