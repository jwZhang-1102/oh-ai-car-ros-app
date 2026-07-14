/**
 * 视频组件 — 用 Web 播 MJPEG（/index2），避免主线程 PixelMap 解码卡死
 */
import web_webview from '@ohos.web.webview'
import { carApi } from '../CarUtill/CarApi'
import { CarEncode } from '../CarUtill/CarEncode'
import { VideoConfig } from '../utils/VideoConfig'

let TAG = 'VideoComponents'

@Component
export struct VideoComponents {
  public static port: number = 6500
  public static ip: string = '10.147.13.194'
  public static enabled: boolean = true
  @State isRecording: boolean = false
  @State pageUrl: string = ''
  @State streamHint: string = '连接中…'
  private controller: web_webview.WebviewController = new web_webview.WebviewController()

  aboutToAppear(): void {
    try {
      web_webview.WebviewController.initializeWebEngine()
    } catch (_e) {
    }
    VideoConfig.syncFromPreferences().then(() => {
      if (VideoComponents.enabled) {
        this.reloadPage()
      }
    })
  }

  aboutToDisappear(): void {
    this.pageUrl = 'about:blank'
  }

  build() {
    Column() {
      if (VideoComponents.enabled) {
        Stack() {
          if (this.pageUrl.length > 0) {
            Web({ src: this.pageUrl, controller: this.controller })
              .width('100%')
              .height('100%')
              .javaScriptAccess(true)
              .domStorageAccess(true)
              .mixedMode(MixedMode.All)
              .onlineImageAccess(true)
              .darkMode(WebDarkMode.Off)
              .onPageEnd(() => {
                this.streamHint = ''
              })
              .onErrorReceive((_event) => {
                this.streamHint = '视频加载失败，点刷新'
                console.error(TAG, 'Web onErrorReceive')
              })
          } else {
            Column({ space: '8vp' }) {
              Text('📷').fontSize('40fp')
              Text(this.streamHint)
                .fontSize('13fp')
                .fontColor(Color.White)
              Text(`${VideoComponents.ip}:${VideoComponents.port}`)
                .fontSize('11fp')
                .fontColor('#9CA3AF')
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .backgroundColor($r('app.color.surface_dark'))
          }

          if (this.streamHint.length > 0 && this.pageUrl.length > 0) {
            Text(this.streamHint)
              .fontSize('11fp')
              .fontColor(Color.White)
              .padding('6vp')
              .backgroundColor('#99000000')
              .borderRadius('6vp')
              .position({ x: '8vp', y: '8vp' })
          }

          if (this.isRecording) {
            Row({ space: '4vp' }) {
              Circle({ width: '8vp', height: '8vp' }).fill('#EF4444')
              Text('REC').fontSize('10fp').fontColor('#EF4444')
            }
            .padding({ left: '8vp', right: '8vp', top: '3vp', bottom: '3vp' })
            .backgroundColor('#99000000')
            .borderRadius('6vp')
            .position({ x: '8vp', y: '8vp' })
          }
        }
        .width('100%')
        .height('200vp')
        .clip(true)
        .borderRadius('16vp')
        .backgroundColor(Color.Black)

        Row({ space: '10vp' }) {
          Button('刷新')
            .fontSize('13fp')
            .fontColor($r('app.color.text_on_light'))
            .backgroundColor($r('app.color.edit_text_background'))
            .borderRadius('8vp')
            .onClick(() => this.reloadPage())

          if (!this.isRecording) {
            Button('拍摄')
              .fontSize('13fp')
              .fontColor(Color.White)
              .backgroundColor($r('app.color.button_background'))
              .borderRadius('8vp')
              .onClick(() => carApi.send(CarEncode.TakePhotosEncode()))
          }

          Button(this.isRecording ? '结束' : '录制')
            .fontSize('13fp')
            .fontColor(Color.White)
            .backgroundColor($r('app.color.button_background'))
            .borderRadius('8vp')
            .onClick(() => {
              if (this.isRecording) {
                carApi.send(CarEncode.CloselRecordingEncode())
              } else {
                carApi.send(CarEncode.StartRecordingEncode())
              }
              this.isRecording = !this.isRecording
            })
        }
      } else {
        Column({ space: '8vp' }) {
          Text('📷').fontSize('40fp')
          Text('未启用视频端口')
            .fontSize('15fp')
            .fontColor($r('app.color.text_on_light'))
          Text('连接页勾选「视频」后连接')
            .fontSize('12fp')
            .fontColor($r('app.color.text_muted'))
        }
        .width('100%')
        .height('200vp')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius('16vp')
        .border({ width: '1vp', color: $r('app.color.card_border'), style: BorderStyle.Dashed })
      }
    }
    .width('100%')
  }

  private reloadPage(): void {
    this.streamHint = '连接中…'
    // 走 /index2 HTML+img，解码在 Web 引擎，不堵 ArkUI 主线程
    this.pageUrl = `http://${VideoComponents.ip}:${VideoComponents.port}/index2?t=${Date.now()}`
    console.info(TAG, 'reloadPage ' + this.pageUrl)
  }
}
