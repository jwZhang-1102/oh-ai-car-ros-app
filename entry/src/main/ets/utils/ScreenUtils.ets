import window from '@ohos.window'
import common from '@ohos.app.ability.common'
import { BusinessError } from '@ohos.base'

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
   * 设置导航栏，状态栏不可见，在api9以后不能使用
   */
  export async function setSystemBarEnable_api9(ctx: common.BaseContext) {
    let windowClass = await window.getLastWindow(ctx)
    await windowClass.setWindowSystemBarEnable([])
  }


  /**
   * 设置导航栏，状态栏不可见，在api9以后不能使用
   */
  export async function setSystemBarEnable_api10(windowStage: window.WindowStage) {
    try {
      let windowClass: window.Window = windowStage.getMainWindowSync(); // 获取应用主窗口
      if (!windowClass) {
        console.error('getMainWindowSync returned null');
        return;
      }
      // 1. 设置窗口全屏
      let isLayoutFullScreen = true;
      windowClass.setWindowLayoutFullScreen(isLayoutFullScreen)
        .then(() => {
          console.info('Succeeded in setting the window layout to full-screen mode.');
        })
        .catch((err: BusinessError) => {
          console.error('Failed to set the window layout to full-screen mode. Cause:' + JSON.stringify(err));
        });
    } catch (e) {
      console.error('setSystemBarEnable_api10 failed: ' + JSON.stringify(e));
    }
  }


  /** 竖屏（主页默认） */
  export function setPortrait(ctx: common.BaseContext) {
    window.getLastWindow(ctx).then((data) => {
      data.setPreferredOrientation(window.Orientation.PORTRAIT, (_err) => {
      })
    })
  }

  /** 横屏（全景/驾驶） */
  export function setLandscape(ctx: common.BaseContext) {
    window.getLastWindow(ctx).then((data) => {
      data.setPreferredOrientation(window.Orientation.LANDSCAPE, (_err) => {
      })
    })
  }


}