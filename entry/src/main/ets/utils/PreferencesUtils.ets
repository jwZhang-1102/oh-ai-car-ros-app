import preferences from '@ohos.data.preferences';

/**首选项对象*/
export class PreferencesUtils {
  /**私有静态实例，懒汉式单例*/
  private static instance: PreferencesUtils | undefined = undefined;

  /**私有构造方法，防止外部直接实例化*/
  private constructor() {
  }

  /**提供一个公共的静态方法返回实例对象*/
  public static getInstance(): PreferencesUtils {
    // 如果对象单例不存在那么构建对象
    if (!PreferencesUtils.instance)
      PreferencesUtils.instance = new PreferencesUtils();
    return PreferencesUtils.instance;
  }

  /**网络工具对象*/
  netUtils: NetInfoPreferencesUtils | null = null

  /*
    * 初始化preferences实例
    * @context  应用上下文
   */
  async init(context: Context) {
    this.netUtils = new NetInfoPreferencesUtils(context)
  }
}

/**
 * 网络配置首选项工具
 */
export class NetInfoPreferencesUtils {
  /**首选项名称*/
  public static readonly NAME = "net_preferences_utils"
  /**KEY IP*/
  public static readonly KEY_IP = "KEY_IP";
  /**KEY IP*/
  public static readonly KEY_TCP_PORT = "KEY_TCP_PORT";
  /**KEY IP*/
  public static readonly KEY_VIDEO_PORT = "KEY_TCP_VIDEO";
  /**首选项实例*/
  private pref: preferences.Preferences | null = null

  /**构造函数*/
  constructor(context: Context) {
    this.init(context)
  }

  /**初始化首首选项实例*/
  private async init(context: Context) {
    let name = NetInfoPreferencesUtils.NAME;
    try {
      this.pref = await preferences.getPreferences(context, name)
      console.log(`preferences[${name}]初始化成功`)
    } catch (err) {
      console.error(`preferences[${name}]初始化失败`)
      console.error('err: ', JSON.stringify(err))
    }
  }

  // ------------------------------对外接口------------------------------

  getIP() {
    if (this.pref === null) {
      return Promise.resolve('10.147.13.194')
    }
    return this.pref.get(NetInfoPreferencesUtils.KEY_IP, '10.147.13.194')
  }

  setIp(v: string) {
    if (this.pref === null) {
      return
    }
    this.pref.put(NetInfoPreferencesUtils.KEY_IP, v);
    this.pref.flush()
  }


  getTcpPort() {
    if (this.pref === null) {
      return Promise.resolve('6000')
    }
    return this.pref.get(NetInfoPreferencesUtils.KEY_TCP_PORT, '6000')
  }

  setTcpPort(v: string) {
    if (this.pref === null) {
      return
    }
    this.pref.put(NetInfoPreferencesUtils.KEY_TCP_PORT, v);
    this.pref.flush()
  }

  setVideoPort(v: string) {
    if (this.pref === null) {
      return
    }
    this.pref.put(NetInfoPreferencesUtils.KEY_VIDEO_PORT, v);
    this.pref.flush()
  }

  getVideoPort() {
    if (this.pref === null) {
      return Promise.resolve('6500')
    }
    return this.pref.get(NetInfoPreferencesUtils.KEY_VIDEO_PORT, '6500')
  }
}

