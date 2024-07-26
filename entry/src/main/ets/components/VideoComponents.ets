import web_webview from '@ohos.web.webview'

let TAG = "VideoComponents"

@Component
export struct VideoComponents {
  controller: web_webview.WebviewController = new web_webview.WebviewController()
  public static port: number = 6500;
  public static ip: string = "192.168.1.11"

  build() {
    Column() {
      Web({
        src: this.getWebSrc(),
        controller: this.controller
      })
        .width('300vp')
        .height('200vp')

    }.justifyContent(FlexAlign.Center)

    .backgroundColor(Color.Red)
  }

  getWebSrc() {
    let v = `http://${VideoComponents.ip}:${VideoComponents.port}/`
    console.log(TAG, "getWebSrc()", v)
    return v

  }
}