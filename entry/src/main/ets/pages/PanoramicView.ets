/**
 * 全景视角 - 全屏横屏摄像机视频
 */
import router from '@ohos.router'
import image from '@ohos.multimedia.image'
import window from '@ohos.window'
import { MjpegFramePoller } from '../utils/MjpegFramePoller'
import { VideoConfig } from '../utils/VideoConfig'
import { PreferencesUtils } from '../utils/PreferencesUtils'

let TAG = 'PanoramicView'

@Entry
@Component
struct PanoramicView {
  @State framePixelMap: image.PixelMap | undefined = undefined
  @State streamHint: string = '连接中…'
  @State showToolbar: boolean = true
  @State ip: string = '192.168.1.100'
  @State videoPort: number = 6500
  private poller: MjpegFramePoller | null = null
  private hideTimer: number = -1
  private windowClass: window.Window | null = null

  aboutToAppear(): void {
    this.enterLandscape()
    this.loadConfig()
  }

  aboutToDisappear(): void {
    this.exitLandscape()
    this.stopStream()
    if (this.hideTimer !== -1) {
      clearTimeout(this.hideTimer)
    }
  }

  async enterLandscape() {
    try {
      let win = await window.getLastWindow(getContext(this))
      this.windowClass = win
      // 切换横屏
      await win.setPreferredOrientation(window.Orientation.LANDSCAPE)
      // 隐藏状态栏和导航栏，实现真正全屏
      await win.setWindowSystemBarEnable([])
      win.setWindowLayoutFullScreen(true)
    } catch (e) {
      console.error(TAG, 'enterLandscape failed: ' + e)
    }
  }

  async exitLandscape() {
    try {
      if (this.windowClass) {
        await this.windowClass.setPreferredOrientation(window.Orientation.PORTRAIT)
        this.windowClass.setWindowLayoutFullScreen(false)
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
      this.videoPort = await net.getVideoPort() as number
    }
    this.startStream()
  }

  build() {
    Stack() {
      // 全屏视频画面
      if (this.framePixelMap !== undefined) {
        Image(this.framePixelMap)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .onClick(() => {
            this.showToolbar = !this.showToolbar
            if (this.showToolbar) {
              this.resetAutoHide()
            }
          })
      } else {
        Column({ space: '8vp' }) {
          Text('📷').fontSize('48fp')
          Text(this.streamHint)
            .fontSize('15fp')
            .fontColor(Color.White)
          Text(`${this.ip}:${this.videoPort}`)
            .fontSize('12fp')
            .fontColor('#9CA3AF')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#1F2937')
      }

      // 半透明悬浮控件（横屏时靠左排列）
      if (this.showToolbar) {
        Column({ space: '12vp' }) {
          // 返回按钮
          Button() {
            Image($r('sys.media.ohos_ic_public_arrow_left'))
              .width('22vp').height('22vp')
              .fillColor(Color.White)
          }
          .width('40vp').height('40vp')
          .backgroundColor('#4D000000')
          .borderRadius('20vp')
          .onClick(() => {
            router.back()
          })

          // 刷新按钮
          Button() {
            Text('⟳')
              .fontSize('18fp')
              .fontColor(Color.White)
          }
          .width('40vp').height('40vp')
          .backgroundColor('#4D000000')
          .borderRadius('20vp')
          .onClick(() => this.restartStream())
        }
        .padding('12vp')
        .position({ x: '12vp', y: '12vp' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }

  private startStream(): void {
    this.stopStream()
    this.streamHint = '连接中…'
    let url = this.getVideoUrl()
    console.info(TAG, 'startStream ' + url)
    this.poller = new MjpegFramePoller(
      (pm: image.PixelMap) => {
        this.applyFrame(pm)
      },
      (msg: string) => {
        this.streamHint = msg
      }
    )
    this.poller.start(url)
    this.resetAutoHide()
  }

  private applyFrame(pm: image.PixelMap): void {
    if (this.framePixelMap !== undefined) {
      this.framePixelMap.release()
    }
    this.framePixelMap = pm
    this.streamHint = ''
  }

  private restartStream(): void {
    if (this.framePixelMap !== undefined) {
      this.framePixelMap.release()
      this.framePixelMap = undefined
    }
    this.streamHint = '连接中…'
    if (this.poller !== null) {
      this.poller.restart(this.getVideoUrl())
    } else {
      this.startStream()
    }
  }

  private stopStream(): void {
    if (this.poller !== null) {
      this.poller.stop()
      this.poller = null
    }
    if (this.framePixelMap !== undefined) {
      this.framePixelMap.release()
      this.framePixelMap = undefined
    }
  }

  private getVideoUrl(): string {
    return `http://${this.ip}:${this.videoPort}/video_feed`
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
