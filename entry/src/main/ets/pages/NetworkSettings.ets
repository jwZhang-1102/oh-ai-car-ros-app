/**
 * 网络设置界面
 */
import { TCPClientManager } from '../tcp/TCPClientManager'
import { TCPClientSendUtils } from '../tcp/TCPClientSendUtils'
import promptAction from '@ohos.promptAction'
import router from '@ohos.router'
import { PreferencesUtils } from '../utils/PreferencesUtils'

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
            }
          })
            .width('300vp')

        }
        .height('100%')
        .width(0)
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

        Blank()
          .width(0)
          .layoutWeight(1)

      }
      .height('100%')
    }
  }
}

@Component
struct LoginComponent {
  // 控件大小
  TextWidth: Length = '80vp';
  FontSize: Length = '20fp'
  //
  @State ip: string = "192.168.1.11"
  @State port: string = "6000"
  @State video: string = "6500"
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
        TextInput({ text: this.ip })
          .onChange((v) => this.ip = v)
          .layoutWeight(1)
      }.width('100%')
      .LoginComponentLineStyle()

      // 端口号
      Row() {
        Text("Port:")
          .width(this.TextWidth)
          .textAlign(TextAlign.End)
          .fontSize(this.FontSize)
        TextInput({ text: this.port })
          .onChange((v) => this.port = v)
          .layoutWeight(1)
      }
      .width('100%')
      .LoginComponentLineStyle()

      // 视频
      Row() {
        Text("Video:")
          .width(this.TextWidth)
          .textAlign(TextAlign.End)
          .fontSize(this.FontSize)
        TextInput({ text: this.video })
          .onChange((v) => this.video = v)
          .layoutWeight(1)
      }.width('100%')
      .LoginComponentLineStyle()

      Button("连接").onClick(() => {

        // 保存网络配置
        this.saveNetConfig()

        this.initNetConfig()
      })
        .width('200vp')
    }
  }

  /**
   * 连接网络
   */
  private async initNetConfig() {

    //
    let address = this.ip;
    // TCP IP、端口定义
    TCPClientManager.getInstance().initNetAddress({
      address: address,
      port: Number.parseInt(this.port)
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
    PreferencesUtils.getInstance().netUtils.getIP().then((v: string) => this.ip = v)
    PreferencesUtils.getInstance().netUtils.getTcpPort().then((v: string) => this.port = v)
    PreferencesUtils.getInstance().netUtils.getVideoPort().then((v: string) => this.video = v)
  }

  /**
   * 保存网络配置
   */
  private async saveNetConfig() {
    PreferencesUtils.getInstance().netUtils.setIp(this.ip)
    PreferencesUtils.getInstance().netUtils.setTcpPort(this.port)
    PreferencesUtils.getInstance().netUtils.setVideoPort(this.video)
  }
}

/**
 * 行样式
 */
@Styles
function LoginComponentLineStyle() {
  .margin('5vp')
}