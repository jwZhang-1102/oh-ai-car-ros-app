import { carApi } from '../CarUtill/CarApi'
import { CarDirection } from '../CarUtill/CarEnum'
import { ButtonShadow } from '../styles/styles'

/**
 * 按键控制UI组件
 */
@Component
struct CarBtnComponents {
  build() {
    Grid() {
      GridItem() {
        Button("左转")
          .fontSize('13fp')
          .backgroundColor($r('app.color.button_background'))
          .shadow(ButtonShadow)
          .width('100%')
          .height('100%')
          .onTouch(this.makeTouchEvent((): void => { carApi.carBtnCtrl(CarDirection.LeftRotate) }))
      }

      GridItem() {
        Button("前")
          .backgroundColor($r('app.color.button_background'))
          .shadow(ButtonShadow)
          .width('100%')
          .height('100%')
          .onTouch(this.makeTouchEvent((): void => { carApi.carBtnCtrl(CarDirection.Front) }))
      }

      GridItem() {
        Button("右转")
          .backgroundColor($r('app.color.button_background'))
          .shadow(ButtonShadow)
          .width('100%')
          .height('100%')
          .onTouch(this.makeTouchEvent((): void => { carApi.carBtnCtrl(CarDirection.RightRotate) }))
      }

      // 第二行
      GridItem() {
        Button("左")
          .backgroundColor($r('app.color.button_background'))
          .shadow(ButtonShadow)
          .width('100%')
          .height('100%')
          .onTouch(this.makeTouchEvent((): void => { carApi.carBtnCtrl(CarDirection.Left) }))
      }

      GridItem() {
        Button("停")
          .backgroundColor($r('app.color.button_background'))
          .shadow(ButtonShadow)
          .width('100%')
          .height('100%')
          .onTouch(this.makeTouchEvent((): void => { carApi.carBtnCtrl(CarDirection.Brake) }))

      }

      GridItem() {
        Button("右")
          .backgroundColor($r('app.color.button_background'))
          .shadow(ButtonShadow)
          .width('100%')
          .height('100%')
          .onTouch(this.makeTouchEvent((): void => { carApi.carBtnCtrl(CarDirection.Right) }))

      }

      // 第三行
      GridItem()

      GridItem() {
        Button("后")
          .backgroundColor($r('app.color.button_background'))
          .shadow(ButtonShadow)
          .width('100%')
          .height('100%')
          .onTouch(this.makeTouchEvent((): void => { carApi.carBtnCtrl(CarDirection.After) }))
      }

      GridItem()
    }
    .width('100%')
    .height('100%')
    .rowsTemplate('1fr 1fr 1fr')
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap('6vp')
    .rowsGap('6vp')
  }

  /**
   * 车辆拥有统一的触摸停止事件，所以通过本函数来构造响应函数
   * @param upEvent
   */
  makeTouchEvent(upEvent: (event?: TouchEvent) => void): (event?: TouchEvent) => void {
    let fun = (event?: TouchEvent): void => {
      // 防御性编程
      if (!event)
        return;

      if (event.type === TouchType.Up) {
        // 如果抬起触摸事件时，暂停车辆移动
        carApi.carBtnCtrl(CarDirection.Stop)
      } else if (event.type === TouchType.Down) {
        // 如果出发触摸事件时响应相应的点击事件
        upEvent(event);
      } else if (event.type === TouchType.Move) {
        // 手指触摸途中不会有相应的响应

      }

    }

    return fun;
  }
}

export { CarBtnComponents }