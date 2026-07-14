import http from '@ohos.net.http'
import image from '@ohos.multimedia.image'

const TAG = 'MjpegFramePoller'
const MAX_BUFFER = 384 * 1024

export interface MjpegPollerOptions {
  /** 显示上限帧率，默认 10，减轻手机解码压力 */
  maxFps?: number
}

/**
 * MJPEG 帧轮询器 — 只解最新完整帧，限流显示。
 * 不做缩放解码（desiredSize 在部分设备上会导致闪退）。
 */
export class MjpegFramePoller {
  private client: http.HttpRequest | null = null
  private buffer: Uint8Array = new Uint8Array(0)
  private running: boolean = false
  private decoding: boolean = false
  private pending: boolean = false
  private lastFrameTs: number = 0
  private minIntervalMs: number = 100
  private frameHandler: (pixelMap: image.PixelMap) => void
  private errorHandler: (message: string) => void

  private dataReceiveHandler = (chunk: ArrayBuffer): void => {
    if (!this.running) {
      return
    }
    this.appendBuffer(chunk)
    if (this.decoding) {
      this.pending = true
      return
    }
    this.processBuffer()
  }

  constructor(
    frameHandler: (pixelMap: image.PixelMap) => void,
    errorHandler: (message: string) => void,
    options?: MjpegPollerOptions
  ) {
    this.frameHandler = frameHandler
    this.errorHandler = errorHandler
    if (options !== undefined && options.maxFps !== undefined && options.maxFps > 0) {
      this.minIntervalMs = Math.floor(1000 / options.maxFps)
    }
  }

  start(url: string): void {
    this.stop()
    this.running = true
    this.buffer = new Uint8Array(0)
    this.decoding = false
    this.pending = false
    this.lastFrameTs = 0
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
    this.decoding = false
    this.pending = false
  }

  restart(url: string): void {
    this.start(url)
  }

  private appendBuffer(chunk: ArrayBuffer): void {
    let incoming = new Uint8Array(chunk)
    if (this.buffer.length + incoming.length > MAX_BUFFER * 2) {
      let keep = this.buffer.subarray(Math.max(0, this.buffer.length - MAX_BUFFER))
      let merged = new Uint8Array(keep.length + incoming.length)
      merged.set(keep, 0)
      merged.set(incoming, keep.length)
      this.buffer = merged
      return
    }
    let merged = new Uint8Array(this.buffer.length + incoming.length)
    merged.set(this.buffer, 0)
    merged.set(incoming, this.buffer.length)
    this.buffer = merged
  }

  private processBuffer(): void {
    if (this.decoding || !this.running) {
      return
    }

    let frame = this.scanLastJpeg()
    if (frame === null) {
      return
    }

    this.buffer = this.buffer.subarray(frame.after)

    let now = Date.now()
    if (this.lastFrameTs > 0 && now - this.lastFrameTs < this.minIntervalMs) {
      return
    }

    this.decoding = true
    let source = image.createImageSource(frame.jpeg)
    source.createPixelMap().then((pm: image.PixelMap) => {
      if (this.running) {
        this.lastFrameTs = Date.now()
        this.frameHandler(pm)
      } else {
        try {
          pm.release()
        } catch (_e) {
        }
      }
    }).catch((e: Object) => {
      console.error(TAG, 'decode error ' + JSON.stringify(e))
    }).finally(() => {
      try {
        source.release()
      } catch (_e) {
      }
      this.decoding = false
      if (this.running && this.pending) {
        this.pending = false
        this.processBuffer()
      }
    })
  }

  private scanLastJpeg(): JpegResult | null {
    let buf = this.buffer
    let len = buf.length
    if (len < 4) {
      return null
    }

    let soi = -1
    let eoi = -1
    for (let i = len - 2; i >= 0; i--) {
      if (buf[i] === 0xFF && buf[i + 1] === 0xD9) {
        eoi = i + 2
        break
      }
    }
    if (eoi < 0) {
      return null
    }
    for (let i = eoi - 2; i >= 0; i--) {
      if (buf[i] === 0xFF && buf[i + 1] === 0xD8) {
        soi = i
        break
      }
    }
    if (soi < 0 || eoi <= soi) {
      return null
    }

    let jpegLen = eoi - soi
    let out = new ArrayBuffer(jpegLen)
    new Uint8Array(out).set(buf.subarray(soi, eoi))
    return new JpegResult(out, eoi)
  }
}

class JpegResult {
  jpeg: ArrayBuffer
  after: number

  constructor(jpeg: ArrayBuffer, after: number) {
    this.jpeg = jpeg
    this.after = after
  }
}
