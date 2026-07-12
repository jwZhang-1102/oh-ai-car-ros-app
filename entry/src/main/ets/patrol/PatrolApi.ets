import http from '@ohos.net.http'
import { PatrolEvent } from './PatrolEventModel'

const TAG = 'PatrolApi'
const DEFAULT_PATROL_PORT = 6700

export class PatrolApi {
  static snapshotUrl(host: string, filename: string, port: number = DEFAULT_PATROL_PORT): string {
    return `http://${host}:${port}/snapshot/${filename}`
  }

  static eventsUrl(host: string, port: number = DEFAULT_PATROL_PORT): string {
    return `http://${host}:${port}/events`
  }

  static async checkHealth(host: string, port: number = DEFAULT_PATROL_PORT): Promise<boolean> {
    let client = http.createHttp()
    try {
      let resp = await client.request(`http://${host}:${port}/health`, {
        method: http.RequestMethod.GET,
        connectTimeout: 5000,
        readTimeout: 5000,
        expectDataType: http.HttpDataType.STRING,
      })
      return resp.responseCode === 200
    } catch (e) {
      console.error(TAG, 'checkHealth error: ' + JSON.stringify(e))
      return false
    } finally {
      client.destroy()
    }
  }

  static async fetchEvents(host: string, port: number = DEFAULT_PATROL_PORT): Promise<PatrolEvent[]> {
    let client = http.createHttp()
    try {
      let url = PatrolApi.eventsUrl(host, port)
      let resp = await client.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 8000,
        readTimeout: 8000,
        expectDataType: http.HttpDataType.STRING,
      })
      if (resp.responseCode !== 200) {
        console.error(TAG, `fetchEvents failed code=${resp.responseCode}`)
        return []
      }
      let body = resp.result as string
      let arr = JSON.parse(body) as Array<Record<string, Object>>
      let list: PatrolEvent[] = []
      for (let i = 0; i < arr.length; i++) {
        list.push(PatrolEvent.fromJson(arr[i]))
      }
      return list
    } catch (e) {
      console.error(TAG, 'fetchEvents error: ' + JSON.stringify(e))
      return []
    } finally {
      client.destroy()
    }
  }
}
