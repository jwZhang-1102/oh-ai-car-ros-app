import http from '@ohos.net.http'
import { PreferencesUtils } from '../utils/PreferencesUtils'
import { VideoComponents } from '../components/VideoComponents'

const TAG = 'VideoConfig'

export class VideoConfig {
  static async syncFromPreferences(): Promise<void> {
    let net = PreferencesUtils.getInstance().netUtils
    if (!net) {
      return
    }
    VideoComponents.ip = await net.getIP() as string
    let portStr = await net.getVideoPort() as string
    if (portStr.trim().length > 0) {
      VideoComponents.port = Number.parseInt(portStr)
    }
    let enableVideo = await net.getEnableVideo() as boolean
    VideoComponents.enabled = enableVideo && portStr.trim().length > 0
  }

  static getStreamUrl(): string {
    return `http://${VideoComponents.ip}:${VideoComponents.port}/video_feed`
  }

  static async checkStreamAvailable(): Promise<boolean> {
    if (!VideoComponents.enabled) {
      return false
    }
    let client = http.createHttp()
    try {
      let resp = await client.request(VideoConfig.getStreamUrl(), {
        method: http.RequestMethod.GET,
        connectTimeout: 5000,
        readTimeout: 5000,
        expectDataType: http.HttpDataType.STRING,
      })
      return resp.responseCode === 200
    } catch (e) {
      console.error(TAG, 'checkStreamAvailable error: ' + JSON.stringify(e))
      return false
    } finally {
      client.destroy()
    }
  }

  static applyFromForm(ip: string, port: string, enableVideo: boolean): void {
    VideoComponents.ip = ip
    VideoComponents.enabled = enableVideo && port.trim().length > 0
    if (port.trim().length > 0) {
      VideoComponents.port = Number.parseInt(port)
    }
  }
}
