/**
 * 按键控制 - 竖屏极简风格
 */
import { carApi } from '../CarUtill/CarApi'
import { CarDirection } from '../CarUtill/CarEnum'

@Component
struct CarBtnComponents {
  build() {
    Grid() {
      GridItem() {
        Column()
      }

      GridItem() {
        Button() {
          Text('▲').fontSize('28fp').fontColor(Color.White)
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.button_background'))
        .borderRadius('14vp')
        .onTouch(this.makeTouchEvent((): void => { carApi.carBtnCtrl(CarDirection.Front) }))
      }

      GridItem() {
        Column()
      }

      GridItem() {
        Button() {
          Text('◀').fontSize('28fp').fontColor(Color.White)
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.button_background'))
        .borderRadius('14vp')
        .onTouch(this.makeTouchEvent((): void => { carApi.carBtnCtrl(CarDirection.Left) }))
      }

      GridItem() {
        Button() {
          Text('■').fontSize('24fp').fontColor(Color.White)
        }
        .width('100%').height('100%')
        .backgroundColor('#EF4444')
        .borderRadius('14vp')
        .onTouch(this.makeTouchEvent((): void => { carApi.carBtnCtrl(CarDirection.Brake) }))
      }

      GridItem() {
        Button() {
          Text('▶').fontSize('28fp').fontColor(Color.White)
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.button_background'))
        .borderRadius('14vp')
        .onTouch(this.makeTouchEvent((): void => { carApi.carBtnCtrl(CarDirection.Right) }))
      }

      GridItem() {
        Button() {
          Text('↺').fontSize('22fp').fontColor(Color.White)
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.button_background'))
        .borderRadius('14vp')
        .onTouch(this.makeTouchEvent((): void => { carApi.carBtnCtrl(CarDirection.LeftRotate) }))
      }

      GridItem() {
        Button() {
          Text('▼').fontSize('28fp').fontColor(Color.White)
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.button_background'))
        .borderRadius('14vp')
        .onTouch(this.makeTouchEvent((): void => { carApi.carBtnCtrl(CarDirection.After) }))
      }

      GridItem() {
        Button() {
          Text('↻').fontSize('22fp').fontColor(Color.White)
        }
        .width('100%').height('100%')
        .backgroundColor($r('app.color.button_background'))
        .borderRadius('14vp')
        .onTouch(this.makeTouchEvent((): void => { carApi.carBtnCtrl(CarDirection.RightRotate) }))
      }
    }
    .width('100%')
    .height('260vp')
    .rowsTemplate('1fr 1fr 1fr')
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap('10vp')
    .rowsGap('10vp')
  }

  makeTouchEvent(upEvent: (event?: TouchEvent) => void): (event?: TouchEvent) => void {
    return (event?: TouchEvent): void => {
      if (!event) return
      if (event.type === TouchType.Up) {
        carApi.carBtnCtrl(CarDirection.Stop)
      } else if (event.type === TouchType.Down) {
        upEvent(event)
      }
    }
  }
}

export { CarBtnComponents }
