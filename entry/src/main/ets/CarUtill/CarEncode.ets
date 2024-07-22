export namespace CarEncode {


  /**
   * /**
   * 车辆控制编码
   * @param speed_x -100 ~ 100
   * @param speed_y -100 ~ 100
   * @returns
   */
  export function CtrlCarEncode(speed_x: number, speed_y: number): string {
    return BaseEncode('10',
      toHex(speed_x + 127, 2) +
      toHex(speed_y + 127, 2)
    );
  }


  /**
   * 通用基础编码能力
   * @param type
   * @param data
   */
  function BaseEncode(type: string, data: string) {
    // 8为基础数据长度
    let size = toHex(data.length + 8, 2);
    // 数据拼接
    let code = `$` + // 开始符号
      `00` + // 车辆类型
      type + // 命令标记
      size + // 数据长度
      data + // 数据主体
      `#` // 结尾标记
    return code;
  }

  /**转16进制*/
  function toHex(num: number, len: number) {
    let hex = num.toString(16);
    while (hex.length < len)
      hex = '0' + hex;
    return hex.toUpperCase(); // 如果需要小写，去掉.toUpperCase()
  }
}