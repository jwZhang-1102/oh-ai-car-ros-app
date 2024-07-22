/**
 * 遥控界面
 */
import { carApi } from '../CarUtill/CarApi';
import { CarDirection } from '../CarUtill/CarEnum';
import { CarBtnComponents } from '../components/CarBtnComponents';

@Entry
@Component
struct RemoteControl {
  @State message: string = 'Hello World';

  build() {
    Row() {
      Column() {
        // 操控按钮
        CarBtnComponents()
          .width('210vp')
          .height('210vp')
          // .visibility(Visibility.None)

        // 遥感控制


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