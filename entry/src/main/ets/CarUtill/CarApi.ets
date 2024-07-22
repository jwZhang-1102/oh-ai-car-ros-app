import { TCPClientManager } from '../tcp/TCPClientManager'
import { TCPClientSendUtils } from '../tcp/TCPClientSendUtils'
import { CarEncode } from './CarEncode';

class CarApi {
  carRunDirection(d: direction) {
    switch (d) {
      case direction.front: //前进
        this.send(CarEncode.CtrlCarEncode(100, 100))
        break;
      case direction.after: //后退
        this.send(CarEncode.CtrlCarEncode(100, 100))
        break;
      case direction.Left: //左
        this.send(CarEncode.CtrlCarEncode(100, 100))
        break;
      case direction.right: //右侧
        this.send(CarEncode.CtrlCarEncode(100, 100))
        break;

      default:
        break;
    }

  }

  send(message: string) {
    TCPClientManager.getInstance().sendMessage(message)
  }
}

/**
 * 运动方向
 */
enum direction {
  /**前进*/
  front = 0,
  /**后退*/
  after = 1,
  /**左移动*/
  Left = 2,
  /**右移动*/
  right = 3
}

let carApi = (new CarApi())

export { carApi, direction }