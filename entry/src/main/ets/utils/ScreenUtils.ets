import window from '@ohos.window'
import common from '@ohos.app.ability.common'

export namespace ScreenUtils {

  /**
   * 保持屏幕常量
   * @param status
   */
  export async function keepScreenOn(ctx: common.BaseContext, status: boolean) {
    // let context = getContext(this) as common.BaseContext
    let windowClass = await window.getLastWindow(ctx) //获取窗口实例
    let isScreenOn = await windowClass.getWindowProperties().isKeepScreenOn //查看屏幕常亮状态
    if (!isScreenOn) {
      await windowClass.setWindowKeepScreenOn(status) //设置窗口常亮或取消
    }
    console.info("屏幕常亮状态： " + isScreenOn)
  }

  /**
   * 设置导航栏，状态栏不可见
   */
  export async function setSystemBar(ctx: common.BaseContext) {
    let windowClass = await window.getLastWindow(this.context)
    await windowClass.setWindowSystemBarEnable([])
  }

  /**
   * 将应用设置为横屏
   */
  export function setLandscape(ctx: common.BaseContext) {
    //将应用设置为横屏
    let promise = window.getLastWindow(ctx);
    promise.then((data) => {
      //切换成横屏
      let orientation = window.Orientation.LANDSCAPE;
      data.setPreferredOrientation(orientation, (err) => {
      });
    })
  }


}