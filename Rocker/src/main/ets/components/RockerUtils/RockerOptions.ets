export type GetImageBitmap = () => ImageBitmap

/**
 * 遥感控制
 */
export interface RockerOptions {
  /**宽度*/
  width?: number;

  /**高度*/
  height?: number;

  /**手指宽度*/
  tiltWidth?: number;

  /** 画布宽度 */
  canveWidth?: number;

  /** 画布高度 */
  canveHeight?: number;

  /** 手指样式 */
  getTiltStyle?: GetImageBitmap;

  /** 背景样式 */
  getBackgroundStyle?: GetImageBitmap;


}