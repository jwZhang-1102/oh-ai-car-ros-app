/**
 * 摇杆绘制 - 极简风格
 */
import { MathUtils } from '../utils/MathUtils';
import { RockerOptions } from './RockerOptions';

const TAG = 'CarRockerDrawUtils';
const isDebug = false;

class RockerDrawUtils {
  rockerOptions: RockerOptions = new RockerOptions();

  constructor(ctx: CanvasRenderingContext2D, rockerOptions?: RockerOptions) {
    this.ctx = ctx;
    if (rockerOptions) this.rockerOptions = rockerOptions;
  }

  public init(rockerOptions?: RockerOptions) {
    if (rockerOptions) this.rockerOptions = rockerOptions;
  }

  private ctx: CanvasRenderingContext2D
  private _tiltX: number = 0
  private _tiltY: number = 0
  private _width: number = 0;
  private _height: number = 0;

  public myOnReadyEvent = () => {
    this.clearCanvas();
    this.drawBackground();
    this.drawRule();
  }

  private clearCanvas() {
    this.ctx.clearRect(0, 0, this.width, this.height);
  }

  private drawBackground() {
    if (this.rockerOptions.getBackgroundStyle) {
      let img = this.rockerOptions.getBackgroundStyle();
      this.ctx.drawImage(img, 0, 0, this.width, this.height);
      return;
    }

    // 极简底盘：浅灰圆 + 细边框
    let w = this.width, h = this.height;
    let cx = w / 2, cy = h / 2, r = Math.min(w, h) / 2 - 2;
    let rule2D: Path2D = new Path2D();
    rule2D.arc(cx, cy, r, 0, Math.PI * 2);
    this.ctx.fillStyle = '#E5E7EB';
    this.ctx.fill(rule2D);
  }

  private drawRule() {
    let tiltR: number = this.FingerRadius;
    tiltR = this.FingerRadius < 1 ? this.width / 2 * tiltR : tiltR;

    let x = MathUtils.mapValue(this.tiltX, 0, this.width, 0 + tiltR, this.width - tiltR)
    let y = MathUtils.mapValue(this.tiltY, 0, this.height, 0 + tiltR, this.height - tiltR)

    if (this.rockerOptions.getTiltStyle) {
      this.ctx.drawImage(this.rockerOptions.getTiltStyle(),
        x - tiltR, y - tiltR, tiltR * 2, tiltR * 2)
      return;
    }

    // 极简旋钮：蓝色实心圆 + 阴影
    this.ctx.fillStyle = '#2563EB';
    let rule2D: Path2D = new Path2D();
    rule2D.arc(x, y, tiltR, 0, Math.PI * 2);
    this.ctx.fill(rule2D);
  }

  public get FingerRadius(): number {
    if (this.rockerOptions.tiltWidth) return this.rockerOptions.tiltWidth;
    return 30;
  }

  public get width(): number { return this._width; }
  public get height(): number { return this._height; }

  public get tiltX(): number {
    if (this._tiltX < 0) return 0
    if (this._tiltX > this.width) return this.width
    return this._tiltX
  }

  public get tiltY(): number {
    if (this._tiltY < 0) return 0;
    if (this._tiltY > this.height) return this.height;
    return this._tiltY
  }

  public setTiltXY(tiltX: number, tiltY: number) {
    this._tiltX = tiltX;
    this._tiltY = tiltY;
  }

  public setSize(width: number, height: number) {
    this._height = height;
    this._width = width;
  }
}

export { RockerDrawUtils }
