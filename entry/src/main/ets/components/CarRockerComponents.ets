import { carApi } from '../CarUtill/CarApi'
import { CarDirection } from '../CarUtill/CarEnum'
import promptAction from '@ohos.promptAction'
import { CarRockerDrawUtils } from './CarRocker/CarRockerDrawUtils';
import { CarEncode } from '../CarUtill/CarEncode';

let TAG = 'anran0';


/**
 * 按键控制UI组件
 */
@Component
struct CarRockerComponents {
  // 用来配置CanvasRenderingContext2D对象的参数，包括是否开启抗锯齿，true表明开启抗锯齿。
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  // 用来创建CanvasRenderingContext2D对象，通过在canvas中调用CanvasRenderingContext2D对象来绘制。
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  // 屏幕绘制工具
  private drawUtils: CarRockerDrawUtils = new CarRockerDrawUtils(this.ctx)
  /**
   * 所需绘制的组件大小
   */
  private AreaValue?: Area

  build() {
    Canvas(this.ctx)
      .onReady(() => {
        //可以在这里绘制内容。
        this.drawUtils.myOnReadyEvent()
      })
      .onTouch((event) => {
        //在这里触发手指移动响应
        this.myOnTouchEvent(event)
      })
      .onAreaChange((oldValue: Area, newValue: Area) => {

        // 显示区域变化监听

        console.info(TAG, `oldValue is ${JSON.stringify(oldValue)} ` +
          `value is ${JSON.stringify(newValue)}`)
        // 组件位置共享
        this.AreaValue = newValue;

        if (this.AreaValue) { // 防御性编程
          let w = (this.AreaValue.width as number)
          let h = (this.AreaValue.height as number)
          //重置手指的位置,在屏幕中央
          this.drawUtils.setTiltXY(w / 2, h / 2)
          // 重置绘制大小
          this.drawUtils.setSize(w, h)
        }

        // 重绘组件
        this.drawUtils.myOnReadyEvent()
      })
      .onClick(() => {
        this.drawUtils.myOnReadyEvent();
      })
  }

  /** 触摸事件*/
  private myOnTouchEvent(event?: TouchEvent) {

    if (!event) return; // 防御性编程


    if (event.type === TouchType.Up) {
      // - 如果抬起触摸事件时

      //重置手指的位置,在屏幕中央
      if (this.AreaValue) { // 防御性编程
        let tiltX = (this.AreaValue.width as number) / 2
        let tiltY = (this.AreaValue.height as number) / 2
        this.drawUtils.setTiltXY(tiltX, tiltY);
      }
      // 重绘界面
      this.drawUtils.myOnReadyEvent();
      // 发送编码字符
      this.sendEncode();
    } else if (event.type === TouchType.Move) {
      // - 手指触摸途中
      // 更新手指位置
      let tiltX = event.touches[0].x
      let tiltY = event.touches[0].y
      this.drawUtils.setTiltXY(tiltX, tiltY);
      //重绘触控UI
      this.drawUtils.myOnReadyEvent()

    } else if (event.type === TouchType.Down) {
      // - 如果出发触摸事件时响应相应的点击事件
    }
  }

  private sendEncode() {
    let l = this.drawUtils.FingerRadius;
    let r = this.drawUtils.width - this.drawUtils.FingerRadius;
    let lr = r - l; // 左右总长

    let sendx = 0;

    sendx = this.drawUtils.tiltX;


    let sendy = this.drawUtils.tiltY;
    carApi.send(CarEncode.CtrlCarEncode(sendx, sendy));
  }
}

export { CarRockerComponents }