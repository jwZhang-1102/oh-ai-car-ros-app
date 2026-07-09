/**
 * 网络设置界面
 */
import { TCPClientManager } from '../tcp/TCPClientManager'
import { TCPClientSendUtils } from '../tcp/TCPClientSendUtils'
import promptAction from '@ohos.promptAction'
import router from '@ohos.router'
import { PreferencesUtils } from '../utils/PreferencesUtils'
import { VideoComponents } from '../components/VideoComponents'
import { ButtonShadow } from '../styles/styles'
import { MyUtils } from '../utils/MyUtils'


@Entry
@Component
struct NetworkSettings {
  // @State message: string = 'Hello World';

  build() {
    Column() {
      // 标题
      Stack() {


      }

      // 主体
      Row() {
        Column() {
          LoginComponent({
            connectSuccessRun: () => {
              // 如果连接成功 打开主页
              router.pushUrl({ url: "pages/Index" })
            },
            connectfailRun: () => {
              // @todo 如果在调试状态，连接失败也打开主页
              if (MyUtils.isDebug)
                router.pushUrl({ url: "pages/Index" })
            }
          })
            .width('300vp')

        }
        .height('100%')
        .width(0)
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

      }
      .height('100%')
    }
    .backgroundColor($r('app.color.window_background'))
  }
}

@Component
struct LoginComponent {
  // 控件大小
  TextWidth: Length = '80vp';
  FontSize: Length = '20fp'
  BlankWidth: Length = '10vp'
  //
  @State ip: string = "10.147.13.194"
  @State tcpPort: string = "6000"
  @State videoPort: string = "6500"
  /**
   * 连接成功运行
   */
  connectSuccessRun = () => {
  }
  /**
   * 连接失败运行
   */
  connectfailRun = () => {
  }

  /**
   * 数据初始化
   */
  aboutToAppear(): void {
    this.readNetConfig();
  }

  build() {
    Column() {
      // IP配置
      Row() {
        Text("IP:")
          .width(this.TextWidth)
          .textAlign(TextAlign.End)
          .fontSize(this.FontSize)
          .fontColor($r('app.color.button_text'))

        Blank().width(this.BlankWidth)

        TextInput({ text: this.ip })
          .onChange((v) => this.ip = v)
          .layoutWeight(1)
          .backgroundColor($r('app.color.edit_text_background'))
      }.width('100%')
      .LoginComponentLineStyle()

      // 端口号
      Row() {
        Text("Port:")
          .width(this.TextWidth)
          .textAlign(TextAlign.End)
          .fontSize(this.FontSize)
          .fontColor($r('app.color.button_text'))

        Blank().width(this.BlankWidth)

        TextInput({ text: this.tcpPort })
          .onChange((v) => this.tcpPort = v)
          .layoutWeight(1)
          .backgroundColor($r('app.color.edit_text_background'))
      }
      .width('100%')
      .LoginComponentLineStyle()

      // 视频
      Row() {
        Text("Video:")
          .width(this.TextWidth)
          .textAlign(TextAlign.End)
          .fontSize(this.FontSize)
          .fontColor($r('app.color.button_text'))

        Blank().width(this.BlankWidth)

        TextInput({ text: this.videoPort })
          .onChange((v) => this.videoPort = v)
          .layoutWeight(1)
          .backgroundColor($r('app.color.edit_text_background'))
      }.width('100%')
      .LoginComponentLineStyle()

      Button("连接").onClick(() => {

        // 保存网络配置
        this.saveNetConfig()
        // 初始化TCP网络配置
        this.initTcpConfig()

        // 初始化视频网络配置
        VideoComponents.ip = this.ip;
        VideoComponents.port = Number.parseInt(this.videoPort)

      })
        .width('200vp')
        .backgroundColor($r('app.color.button_background'))
        .shadow(ButtonShadow)
    }
  }

  /**
   * 连接网络
   */
  private async initTcpConfig() {

    //
    let address = this.ip;
    // TCP IP、端口定义
    TCPClientManager.getInstance().initNetAddress({
      address: address,
      port: Number.parseInt(this.tcpPort)
    });
    // 创建TCP连接
    let isConnect = await TCPClientManager.getInstance().connect();
    if (isConnect) {
      // 如果连接成功
      promptAction.showToast({ message: "连接成功" })
      // 初始化心跳包等网络信息
      TCPClientSendUtils.getInstance().init();
      // 触发连接成功回调
      this.connectSuccessRun();
    } else {

      promptAction.showToast({ message: "连接失败，请检查信息" })
      // 触发连接失败回调
      this.connectfailRun();
    }
  }

  /**
   * 从本地首选项读取偏好设置
   */
  private readNetConfig() {
    const netUtils = PreferencesUtils.getInstance().netUtils
    if (!netUtils) {
      return
    }
    netUtils.getIP().then((v) => { this.ip = v as string })
    netUtils.getTcpPort().then((v) => { this.tcpPort = v as string })
    netUtils.getVideoPort().then((v) => { this.videoPort = v as string })
  }

  /**
   * 保存网络配置
   */
  private async saveNetConfig() {
    const netUtils = PreferencesUtils.getInstance().netUtils
    if (!netUtils) {
      return
    }
    netUtils.setIp(this.ip)
    netUtils.setTcpPort(this.tcpPort)
    netUtils.setVideoPort(this.videoPort)
  }
}

/**
 * 行样式
 */
@Styles
function LoginComponentLineStyle() {
  .margin('5vp')
}