import { carApi } from '../CarUtill/CarApi'
import { CarEncode } from '../CarUtill/CarEncode';

import { RockerComponent, RockerOptions } from "rocker"

/**
 * 摇杆控制 UI 组件
 */
@Component
struct CarRockerComponents {
  /**
   * 不使用 SVG ImageBitmap：OpenHarmony 上 Canvas.drawImage 对 SVG 支持不稳定，
   * 会导致摇杆不可见但仍可触控。改用 RockerDrawUtils 默认圆形绘制。
   */
  build() {
    RockerComponent({
      rockerOptions: new RockerOptions({
        tiltWidth: 0.35,
        tiltEvent: (tiltX: number, tiltY: number, event?: TouchEvent) => {
          carApi.send(CarEncode.CtrlCarEncode(tiltX, tiltY));
        }
      })
    })
      .width('100%')
      .height('100%')
  }
}

export { CarRockerComponents }
