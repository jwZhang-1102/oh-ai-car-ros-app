/**
 * 遥控界面
 */
import { carApi } from '../CarUtill/CarApi';
import { CarDirection } from '../CarUtill/CarEnum';
import { CarBtnComponents } from '../components/CarBtnComponents';
import { CarRockerComponents } from '../components/CarRockerComponents';

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
          .visibility(Visibility.None)
          .border({width:1,color:Color.Black})


        // 遥感控制
        CarRockerComponents()
          .width('210vp')
          .height('210vp')
          .border({width:1,color:Color.Black})

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