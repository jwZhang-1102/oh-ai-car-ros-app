var TAG = 'CarRockerDrawUtils';
var isDebug = true;


class CarRockerDrawUtils {
  //构造函数
  constructor(ctx: CanvasRenderingContext2D) {
    this.ctx = ctx;
  }

  // ---------------常量------------------------------


  /**手指绘制大小半径*/
  readonly FingerRadius: number = 25;
  // ---------------对象------------------------------
  /**画布*/
  private ctx: CanvasRenderingContext2D
  // ---------------变量------------------------------
  /**手指触摸的X轴*/
  private _tiltX: number = 0
  /**手指触摸的Y轴*/
  private _tiltY: number = 0
  /**屏幕绘制的宽度*/
  private _width: number = 0;
  /**屏幕绘制的高度*/
  private _height: number = 0;

  /** 绘制事件（总）*/
  public myOnReadyEvent() {


    // 1.初始化数据

    let w = this.width, h = this.height

    // 2.清除画布上的内容
    this.ctx.clearRect(0, 0, w, h);


    // 3.绘制背景图像
    this.ctx.strokeStyle = '#000'
    this.ctx.stroke(this.newBlack2D())

    // 4.绘制手指图像
    this.ctx.fillStyle = '#999'
    this.ctx.fill(this.newRule2D())

    console.log(TAG, `myOnReadyEvent End`)
  }

  /**
   * 绘制背景
   * @returns
   */
  private newBlack2D() {
    let rule2D: Path2D = new Path2D();
    let w = this.width, h = this.height; //组件宽高
    rule2D.arc(w / 2, h / 2, w / 2, 0, 360);
    return rule2D;
  }

  /**
   * 绘制手指
   * @returns
   */
  private newRule2D() {
    let rule2D: Path2D = new Path2D();

    let x = this.tiltX;
    let y = this.tiltY;
    rule2D.arc(x, y, this.FingerRadius, 0, 360);
    return rule2D;
  }

  // ---------------------------getder---------------------------
  public get width(): number {
    return this._width;
  }

  public get height(): number {
    return this._height;
  }

  public get tiltX(): number {
    // 如果左侧越界，那么返回边界
    if (this._tiltX < this.FingerRadius)
      return this.FingerRadius
    // 如果右侧越界，那么返回边界
    if (this._tiltX > this.width - this.FingerRadius)
      return this.width - this.FingerRadius
    // 正常返回
    return this._tiltX
  }

  public get tiltY(): number {

    // 如果左侧越界，那么返回边界
    if (this._tiltY < this.FingerRadius)
      return this.FingerRadius
    // 如果右侧越界，那么返回边界
    if (this._tiltY > this.height - this.FingerRadius)
      return this.height - this.FingerRadius
    // 正常返回
    return this._tiltY
  }

  // ---------------------------setder---------------------------
  /**
   * 初始化手指位置
   * @param tiltX 手指的x轴
   * @param tiltY 手指的y轴
   */
  public setTiltXY(tiltX: number, tiltY: number) {
    this._tiltX = tiltX;
    this._tiltY = tiltY;

    if (isDebug) console.log(TAG, "setTiltXY", "tiltY=", this.tiltY, "tiltX=", this.tiltX)

  }

  /**
   * 设置绘制的大小
   * @param width 绘制的宽度
   * @param height 绘制的高度
   */
  public setSize(width: number, height: number) {
    this._height = height;
    this._width = height;
  }
}

export { CarRockerDrawUtils }