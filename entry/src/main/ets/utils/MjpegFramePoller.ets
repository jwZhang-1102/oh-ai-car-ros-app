import http from '@ohos.net.http'
import image from '@ohos.multimedia.image'

const TAG = 'MjpegFramePoller'

/** 通过 requestInStream 持续读取 MJPEG，逐帧解码显示 */
export class MjpegFramePoller {
  private client: http.HttpRequest | null = null
  private buffer: Uint8Array = new Uint8Array(0)
  private running: boolean = false
  private decoding: boolean = false
  private frameHandler: (pixelMap: image.PixelMap) => void
  private errorHandler: (message: string) => void
  private dataReceiveHandler = (chunk: ArrayBuffer): void => {
    if (!this.running) {
      return
    }
    this.appendBuffer(chunk)
    this.processBuffer()
  }

  constructor(frameHandler: (pixelMap: image.PixelMap) => void, errorHandler: (message: string) => void) {
    this.frameHandler = frameHandler
    this.errorHandler = errorHandler
  }

  start(url: string): void {
    this.stop()
    this.running = true
    this.buffer = new Uint8Array(0)
    this.client = http.createHttp()
    this.client.on('dataReceive', this.dataReceiveHandler)

    this.client.requestInStream(url, {
      method: http.RequestMethod.GET,
      connectTimeout: 10000,
      readTimeout: 120000,
    }).then((code: number) => {
      console.info(TAG, 'stream opened code=' + code + ' url=' + url)
      if (code !== 200) {
        this.errorHandler('HTTP ' + code)
      }
    }).catch((err: Object) => {
      console.error(TAG, 'stream error ' + JSON.stringify(err))
      if (this.running) {
        this.errorHandler('拉流失败，请点刷新')
      }
    })
  }

  stop(): void {
    this.running = false
    if (this.client !== null) {
      this.client.off('dataReceive', this.dataReceiveHandler)
      this.client.destroy()
      this.client = null
    }
    this.buffer = new Uint8Array(0)
  }

  restart(url: string): void {
    this.start(url)
  }

  private appendBuffer(chunk: ArrayBuffer): void {
    let incoming = new Uint8Array(chunk)
    let merged = new Uint8Array(this.buffer.length + incoming.length)
    merged.set(this.buffer, 0)
    merged.set(incoming, this.buffer.length)
    this.buffer = merged
  }

  private processBuffer(): void {
    if (this.decoding) {
      return
    }
    let frameData = MjpegFramePoller.copyFirstJpeg(this.buffer)
    if (frameData === null) {
      if (this.buffer.length > 512 * 1024) {
        this.buffer = this.buffer.subarray(this.buffer.length - 128 * 1024)
      }
      return
    }
    this.buffer = this.buffer.subarray(frameData.consumed)
    this.decoding = true
    let source = image.createImageSource(frameData.data)
    source.createPixelMap().then((pm: image.PixelMap) => {
      if (this.running) {
        this.frameHandler(pm)
      } else {
        pm.release()
      }
    }).catch((e: Object) => {
      console.error(TAG, 'decode error ' + JSON.stringify(e))
    }).finally(() => {
      source.release()
      this.decoding = false
      if (this.running) {
        this.processBuffer()
      }
    })
  }

  private static copyFirstJpeg(bytes: Uint8Array): FrameData | null {
    let start = -1
    for (let i = 0; i < bytes.length - 1; i++) {
      if (bytes[i] === 0xFF && bytes[i + 1] === 0xD8) {
        start = i
        break
      }
    }
    if (start < 0) {
      return null
    }
    let end = -1
    for (let i = start + 2; i < bytes.length - 1; i++) {
      if (bytes[i] === 0xFF && bytes[i + 1] === 0xD9) {
        end = i + 2
        break
      }
    }
    if (end <= start) {
      return null
    }
    let jpegLen = end - start
    let out = new ArrayBuffer(jpegLen)
    new Uint8Array(out).set(bytes.subarray(start, end))
    let frame = new FrameData()
    frame.data = out
    frame.consumed = end
    return frame
  }
}

class FrameData {
  data: ArrayBuffer = new ArrayBuffer(0)
  consumed: number = 0
}
