import image from '@ohos.multimedia.image'
import { carApi } from '../CarUtill/CarApi'
import { CarEncode } from '../CarUtill/CarEncode'
import { MjpegFramePoller } from '../utils/MjpegFramePoller'
import { VideoConfig } from '../utils/VideoConfig'
import { ButtonShadow } from '../styles/styles'

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
      if (VideoComponents.enabled) {
        this.startStream()
      }
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
            Column({ space: '6vp' }) {
              Text(this.streamHint)
                .fontSize('13fp')
                .fontColor(Color.White)
              Text(`${VideoComponents.ip}:${VideoComponents.port}`)
                .fontSize('11fp')
                .fontColor('#AAAAAA')
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
          }

          if (this.isRecording) {
            RedRound()
              .width('10vp')
              .height('10vp')
              .position({ x: '260vp', y: '170vp' })
          }
        }
        .width('300vp')
        .height('200vp')
        .backgroundColor(Color.Black)
        .clip(true)
        .borderRadius('4vp')

        Row({ space: '10vp' }) {
          Button('刷新')
            .fontSize('14fp')
            .backgroundColor($r('app.color.card_background'))
            .fontColor($r('app.color.text_on_light'))
            .onClick(() => {
              this.restartStream()
            })

          if (this.isRecording == false) {
            Button('拍摄')
              .backgroundColor($r('app.color.button_background'))
              .shadow(ButtonShadow)
              .onClick(() => {
                carApi.send(CarEncode.TakePhotosEncode())
              })
          }

          Button(this.isRecording == false ? '录制' : '结束')
            .backgroundColor($r('app.color.button_background'))
            .shadow(ButtonShadow)
            .onClick(() => {
              if (this.isRecording == true) {
                carApi.send(CarEncode.CloselRecordingEncode())
              } else {
                carApi.send(CarEncode.StartRecordingEncode())
              }
              this.isRecording = !this.isRecording
            })
        }
      } else {
        Column({ space: '6vp' }) {
          Text('未启用视频端口')
            .fontSize('15fp')
            .fontColor($r('app.color.text_on_light'))
          Text('连接页勾选「视频」后连接')
            .fontSize('12fp')
            .fontColor($r('app.color.text_muted'))
        }
        .width('300vp')
        .height('200vp')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius('10vp')
        .border({ width: '1vp', color: $r('app.color.card_border'), style: BorderStyle.Dashed })
      }
    }
    .justifyContent(FlexAlign.Center)
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

  getVideoUrl(): string {
    return `http://${VideoComponents.ip}:${VideoComponents.port}/video_feed`
  }
}

@Component
struct RedRound {
  @State isShow: boolean = true

  aboutToAppear(): void {
    setInterval(() => {
      this.isShow = !this.isShow
    }, 1000)
  }

  build() {
    Text()
      .width('10vp')
      .height('10vp')
      .backgroundColor(Color.Red)
      .animation({
        duration: 1200,
        curve: Curve.Friction,
        delay: 500,
        iterations: -1,
      })
      .border({ radius: '5vp' })
      .visibility(this.isShow ? Visibility.Visible : Visibility.None)
  }
}
