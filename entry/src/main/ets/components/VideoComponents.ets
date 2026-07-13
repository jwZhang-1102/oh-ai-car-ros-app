/**
 * 视频组件 - 极简风格
 */
import image from '@ohos.multimedia.image'
import { carApi } from '../CarUtill/CarApi'
import { CarEncode } from '../CarUtill/CarEncode'
import { MjpegFramePoller } from '../utils/MjpegFramePoller'
import { VideoConfig } from '../utils/VideoConfig'

let TAG = 'VideoComponents'

@Component
export struct VideoComponents {
  public static port: number = 6500
  public static ip: string = '10.147.13.194'
  public static enabled: boolean = true
  @State isRecording: boolean = false
  @State framePixelMap: image.PixelMap | undefined = undefined
  @State streamHint: string = '连接中…'
  private poller: MjpegFramePoller | null = null

  aboutToAppear(): void {
    VideoConfig.syncFromPreferences().then(() => {
      if (VideoComponents.enabled) this.startStream()
    })
  }

  aboutToDisappear(): void {
    this.stopStream()
  }

  build() {
    Column() {
      if (VideoComponents.enabled) {
        Stack() {
          if (this.framePixelMap !== undefined) {
            Image(this.framePixelMap)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
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

        Row({ space: '10vp' }) {
          Button('刷新')
            .fontSize('13fp')
            .fontColor($r('app.color.text_on_light'))
            .backgroundColor($r('app.color.edit_text_background'))
            .borderRadius('8vp')
            .onClick(() => this.restartStream())

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
  }

  private applyFrame(pm: image.PixelMap): void {
    if (this.framePixelMap !== undefined) this.framePixelMap.release()
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

  getVideoUrl(): string {
    return `http://${VideoComponents.ip}:${VideoComponents.port}/video_feed`
  }
}
