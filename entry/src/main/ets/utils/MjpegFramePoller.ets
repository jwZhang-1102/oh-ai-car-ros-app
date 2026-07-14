import http from '@ohos.net.http'
import image from '@ohos.multimedia.image'

const TAG = 'MjpegFramePoller'
const MAX_BUFFER = 384 * 1024

/**
 * MJPEG 帧轮询器 — 通过 requestInStream 拉流，逐帧解码显示。
 *
 * 优化要点：
 * - 从 buffer 尾部倒搜最后一帧 JPEG，扫描范围 O(最后一帧大小)
 * - 每轮只处理一帧，不递归积压
 * - 丢弃积压旧帧，保证遥控画面低延迟
 */
export class MjpegFramePoller {
  private client: http.HttpRequest | null = null
  private buffer: Uint8Array = new Uint8Array(0)
  private running: boolean = false
  private decoding: boolean = false
  private pending: boolean = false         // 解码期间是否有新数据到达
  private frameHandler: (pixelMap: image.PixelMap) => void
  private errorHandler: (message: string) => void

  private dataReceiveHandler = (chunk: ArrayBuffer): void => {
    if (!this.running) return
    this.appendBuffer(chunk)
    if (this.decoding) {
      this.pending = true    // 标记有新数据，解码完再处理
      return
    }
    this.processBuffer()
  }

  constructor(
    frameHandler: (pixelMap: image.PixelMap) => void,
    errorHandler: (message: string) => void
  ) {
    this.frameHandler = frameHandler
    this.errorHandler = errorHandler
  }

  // ── 公开方法 ──────────────────────────────────

  start(url: string): void {
    this.stop()
    this.running = true
    this.buffer = new Uint8Array(0)
    this.decoding = false
    this.pending = false
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

  // ── 内部 ──────────────────────────────────────

  /** 追加数据到 buffer（简单拼接） */
  private appendBuffer(chunk: ArrayBuffer): void {
    let incoming = new Uint8Array(chunk)
    // 防止无限膨胀：过大的旧数据直接截断
    if (this.buffer.length + incoming.length > MAX_BUFFER * 2) {
      let keep = this.buffer.subarray(this.buffer.length - MAX_BUFFER)
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

  /** 从尾部倒搜最后一帧 → 解码 → 丢掉之前的旧数据 */
  private processBuffer(): void {
    if (this.decoding) return

    let frame = this.scanLastJpeg()
    if (frame === null) return

    // 取出帧数据，丢弃它之前的所有旧数据
    this.buffer = this.buffer.subarray(frame.after)
    this.decoding = true

    let source = image.createImageSource(frame.jpeg)
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
      // 解码期间如果又来了新数据，继续处理最新一帧
      if (this.running && this.pending) {
        this.pending = false
        // 只保留最后一帧之前的数据，中间积压的全丢掉
        let latest = this.scanLastJpeg()
        if (latest !== null) {
          this.buffer = this.buffer.subarray(latest.after)
        }
        this.processBuffer()
      }
    })
  }

  /**
   * 从 buffer 尾部倒搜最后一个完整 JPEG 帧。
   * 返回 { jpeg, after } 或 null。
   */
  private scanLastJpeg(): JpegResult | null {
    let buf = this.buffer
    let len = buf.length
    if (len < 4) return null

    // Step 1: 从尾部找 JPEG 结束标记 0xFFD9
    let soi = -1  // Start of Image (0xFFD8)
    let eoi = -1  // End of Image (0xFFD9)

    for (let i = len - 2; i >= 0; i--) {
      if (buf[i] === 0xFF && buf[i + 1] === 0xD9) {
        eoi = i + 2
        break
      }
    }
    if (eoi < 0) return null

    // Step 2: 从 EOI 往前找最近的 0xFFD8
    for (let i = eoi - 2; i >= 0; i--) {
      if (buf[i] === 0xFF && buf[i + 1] === 0xD8) {
        soi = i
        break
      }
    }
    if (soi < 0) return null
    if (eoi <= soi) return null

    // 提取 JPEG 数据
    let jpegLen = eoi - soi
    let out = new ArrayBuffer(jpegLen)
    new Uint8Array(out).set(buf.subarray(soi, eoi))

    return new JpegResult(out, eoi)
  }
}

/** 帧扫描结果 */
class JpegResult {
  jpeg: ArrayBuffer
  after: number   // 帧结束位置（buffer 应从此处截断）

  constructor(jpeg: ArrayBuffer, after: number) {
    this.jpeg = jpeg
    this.after = after
  }
}
