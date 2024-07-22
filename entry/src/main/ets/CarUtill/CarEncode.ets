export namespace CarEncode {


  /**
   * /**
   * 车辆控制编码
   * @param speed_x -100 ~ 100
   * @param speed_y -100 ~ 100
   * @returns
   */
  export function CtrlCarEncode(speed_x: number, speed_y: number): string {
    if (speed_x < 0) speed_x += 255
    if (speed_y < 0) speed_y += 255
    return BaseEncode('10',
      numberToHex(speed_x , 2) +
      numberToHex(speed_y , 2)
    );
  }


  /**
   * 通用基础编码能力
   * @param type
   * @param data
   */
  function BaseEncode(type: string, data: string) {
    // 8为基础数据长度
    let size = numberToHex(data.length + 2, 2);

    // 数据拼接
    let code = '01' + //车辆类型
      type + // 命令标记
      size + // 数据长度
      data // 数据主体

    code += numberToHex(getCheckChecksum(code), 2);

    //$ 车辆类型  数据 #
    // 添加开始结束符
    code = `$${code}#`

    console.log('BaseEncode' + code);
    return code;
  }

  /**数字转十六进制*/
  function numberToHex(num: number, len: number) {
    let hex = num.toString(16);
    while (hex.length < len)
      hex = '0' + hex;
    return hex.toUpperCase(); // 如果需要小写，去掉.toUpperCase()
  }


  function getCheckChecksum(data: string) {
    console.log("getCheckChecksum", data)
    // 初始化校验和变量
    let dataSize = data.length;
    let calculatedChecksum = 0;

    // 计算校验和（跳过最后两个字符）
    for (let i = 0; i < dataSize; i += 2) {
      // 每次处理两个字符（一个字节）
      const byte = parseInt(data.substr(i, 2), 16);
      calculatedChecksum = (calculatedChecksum + byte) % 256;
    }
    // 返回校验值状态
    return calculatedChecksum
  }

  /**
   * 十六进制转数字
   * @param hexString
   * @returns
   */
  function hexToNumber(hexString: string) {
    let number = parseInt(hexString, 16);
    return number;
  }
}