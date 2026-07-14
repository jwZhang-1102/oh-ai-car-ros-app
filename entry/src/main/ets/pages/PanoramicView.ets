/**
 * 全景视角
 * 真机旋转锁时：整页（视频 Web + 工具栏）一起 ArkUI 旋转 90°。
 * 不要依赖 Web 内 CSS 旋转（Harmony 真机经常不生效）。
 */
import router from '@ohos.router'
import window from '@ohos.window'
import web_webview from '@ohos.web.webview'
import { VideoConfig } from '../utils/VideoConfig'
import { PreferencesUtils } from '../utils/PreferencesUtils'
import { VideoComponents } from '../components/VideoComponents'

let TAG = 'PanoramicView'

@Entry
@Component
struct PanoramicView {
  @State pageUrl: string = ''
  @State streamHint: string = '连接中…'
  @State showToolbar: boolean = true
  @State ip: string = '192.168.1.100'
  @State videoPort: number = 6500
  /** 默认按伪横屏，避免首帧竖屏视频 + 横屏按钮错位 */
  @State fakeLandscape: boolean = true
  @State areaW: number = 0
  @State areaH: number = 0
  private hideTimer: number = -1
  private orientTimer: number = -1
  private windowClass: window.Window | null = null
  private controller: web_webview.WebviewController = new web_webview.WebviewController()

  aboutToAppear(): void {
    try {
      web_webview.WebviewController.initializeWebEngine()
    } catch (_e) {
    }
    this.fakeLandscape = true
    this.enterLandscape()
    this.loadConfig()
  }

  aboutToDisappear(): void {
    if (this.orientTimer !== -1) {
      clearTimeout(this.orientTimer)
      this.orientTimer = -1
    }
    this.exitLandscape()
    this.pageUrl = 'about:blank'
    if (this.hideTimer !== -1) {
      clearTimeout(this.hideTimer)
    }
  }

  onPageShow(): void {
    this.enterLandscape()
  }

  async enterLandscape() {
    try {
      let win = await window.getLastWindow(getContext(this))
      this.windowClass = win
      await win.setWindowSystemBarEnable([])
      await win.setWindowLayoutFullScreen(true)

      const candidates: window.Orientation[] = [
        window.Orientation.USER_ROTATION_LANDSCAPE,
        window.Orientation.LANDSCAPE,
        window.Orientation.AUTO_ROTATION_LANDSCAPE
      ]
      for (let i = 0; i < candidates.length; i++) {
        try {
          await win.setPreferredOrientation(candidates[i])
          console.info(TAG, 'setOrientation ok: ' + candidates[i])
          break
        } catch (e) {
          console.warn(TAG, 'setOrientation fail ' + candidates[i] + ': ' + e)
        }
      }

      if (this.orientTimer !== -1) {
        clearTimeout(this.orientTimer)
      }
      this.orientTimer = setTimeout(() => {
        this.orientTimer = -1
        this.syncFakeFromWindow(win)
        win.setPreferredOrientation(window.Orientation.USER_ROTATION_LANDSCAPE).catch(() => {
          win.setPreferredOrientation(window.Orientation.LANDSCAPE).catch(() => {
          })
        })
        setTimeout(() => {
          this.syncFakeFromWindow(win)
        }, 400)
      }, 280)
    } catch (e) {
      console.error(TAG, 'enterLandscape failed: ' + e)
      this.fakeLandscape = true
    }
  }

  private syncFakeFromWindow(win: window.Window): void {
    try {
      let rect = win.getWindowProperties().windowRect
      // 已是横屏窗口：关掉伪横屏；否则保持伪横屏
      if (rect.width > 0 && rect.height > 0 && rect.width >= rect.height) {
        this.fakeLandscape = false
      } else {
        this.fakeLandscape = true
      }
      console.info(TAG, `window ${rect.width}x${rect.height} fake=${this.fakeLandscape}`)
    } catch (_e) {
      this.fakeLandscape = true
    }
  }

  async exitLandscape() {
    try {
      if (this.windowClass) {
        try {
          await this.windowClass.setPreferredOrientation(window.Orientation.USER_ROTATION_PORTRAIT)
        } catch (_e) {
          await this.windowClass.setPreferredOrientation(window.Orientation.PORTRAIT)
        }
        await this.windowClass.setWindowLayoutFullScreen(false)
        await this.windowClass.setWindowSystemBarEnable(['status', 'navigation'])
        this.windowClass = null
      }
    } catch (e) {
      console.error(TAG, 'exitLandscape failed: ' + e)
    }
  }

  async loadConfig() {
    await VideoConfig.syncFromPreferences()
    let net = PreferencesUtils.getInstance().netUtils
    if (net) {
      this.ip = await net.getIP() as string
      let portVal = await net.getVideoPort()
      this.videoPort = Number.parseInt(`${portVal}`)
      if (Number.isNaN(this.videoPort)) {
        this.videoPort = VideoComponents.port
      }
    } else {
      this.ip = VideoComponents.ip
      this.videoPort = VideoComponents.port
    }
    this.reloadPage()
  }

  /** 铺满 Web 内容区，不做 CSS 旋转 */
  private buildViewerHtml(feedUrl: string): string {
    return '<!DOCTYPE html><html><head><meta charset="utf-8"/>' +
      '<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"/>' +
      '<style>' +
      '*{margin:0;padding:0;box-sizing:border-box;}' +
      'html,body{width:100%;height:100%;background:#000;overflow:hidden;}' +
      'img{position:absolute;left:0;top:0;width:100%;height:100%;object-fit:cover;background:#000;border:0;}' +
      '</style></head><body>' +
      '<img id="v" alt="video"/>' +
      '<script>document.getElementById("v").src=' + JSON.stringify(feedUrl) + ';</script>' +
      '</body></html><!--' + Date.now() + '-->'
  }

  private paintVideoStyles(): void {
    try {
      this.controller.runJavaScript(
        "document.documentElement.style.background='#000';" +
          "document.body.style.margin='0';document.body.style.background='#000';" +
          "document.body.style.width='100%';document.body.style.height='100%';" +
          "var i=document.querySelector('img');" +
          "if(i){i.style.cssText='position:absolute;left:0;top:0;width:100%;height:100%;object-fit:cover;background:#000;';}"
      )
    } catch (_e) {
    }
  }

  @Builder
  ContentLayer() {
    if (this.pageUrl.length > 0) {
      Web({ src: this.pageUrl, controller: this.controller })
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .mixedMode(MixedMode.All)
        .onlineImageAccess(true)
        .darkMode(WebDarkMode.Off)
        .onClick(() => {
          this.showToolbar = !this.showToolbar
          if (this.showToolbar) {
            this.resetAutoHide()
          }
        })
        .onPageEnd(() => {
          this.streamHint = ''
          this.paintVideoStyles()
        })
        .onErrorReceive((_event) => {
          this.streamHint = '视频加载失败，点刷新'
        })
    } else {
      Column({ space: '8vp' }) {
        Text('全景视角').fontSize('20fp').fontColor(Color.White)
        Text(this.streamHint).fontSize('15fp').fontColor(Color.White)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Color.Black)
    }

    if (this.showToolbar) {
      Row({ space: '12vp' }) {
        Button() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width('22vp').height('22vp')
            .fillColor(Color.White)
        }
        .width('44vp').height('44vp')
        .backgroundColor('#4D000000')
        .borderRadius('22vp')
        .onClick(() => {
          router.back()
        })

        Button() {
          Text('刷新').fontSize('14fp').fontColor(Color.White)
        }
        .height('44vp')
        .padding({ left: '16vp', right: '16vp' })
        .backgroundColor('#4D000000')
        .borderRadius('22vp')
        .onClick(() => this.reloadPage())
      }
      .padding('16vp')
      .position({ x: 0, y: 0 })
    }

    if (this.streamHint.length > 0) {
      Text(this.streamHint)
        .fontSize('12fp')
        .fontColor(Color.White)
        .padding('8vp')
        .backgroundColor('#99000000')
        .borderRadius('8vp')
        .position({ x: '16vp', y: '72vp' })
    }
  }

  build() {
    Stack() {
      if (this.fakeLandscape && this.areaW > 1 && this.areaH > 1 && this.areaW < this.areaH) {
        // 横屏内容区：宽=手机高，高=手机宽，整体旋转 90°，与工具栏同一层
        Stack() {
          this.ContentLayer()
        }
        .width(this.areaH)
        .height(this.areaW)
        .backgroundColor(Color.Black)
        .clip(true)
        .rotate({
          angle: 90,
          centerX: this.areaH / 2,
          centerY: this.areaW / 2
        })
        .position({
          x: (this.areaW - this.areaH) / 2,
          y: (this.areaH - this.areaW) / 2
        })
      } else {
        Stack() {
          this.ContentLayer()
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .onAreaChange((_old, area) => {
      let w = Number(area.width)
      let h = Number(area.height)
      if (w <= 0 || h <= 0) {
        return
      }
      this.areaW = w
      this.areaH = h
      // 真实横屏窗口才关伪横屏
      if (w >= h) {
        this.fakeLandscape = false
      } else {
        this.fakeLandscape = true
      }
    })
  }

  private reloadPage(): void {
    this.streamHint = '连接中…'
    let feed = `http://${this.ip}:${this.videoPort}/video_feed`
    this.pageUrl = 'data:text/html;charset=utf-8,' + encodeURIComponent(this.buildViewerHtml(feed))
    console.info(TAG, 'reloadPage fake=' + this.fakeLandscape + ' ' + feed)
    this.resetAutoHide()
  }

  private resetAutoHide(): void {
    if (this.hideTimer !== -1) {
      clearTimeout(this.hideTimer)
    }
    this.hideTimer = setTimeout(() => {
      this.showToolbar = false
      this.hideTimer = -1
    }, 3000)
  }
}
