/**
 * 巡检事件（与 Jetson events.jsonl 字段对应）
 */
export class PatrolEvent {
  id: string = ''
  time: string = ''
  className: string = ''
  confidence: number = 0
  snapshot: string = ''

  static fromJson(obj: Record<string, Object>): PatrolEvent {
    let e = new PatrolEvent()
    e.id = String(obj['id'] ?? '')
    e.time = String(obj['time'] ?? '')
    e.className = String(obj['class'] ?? '')
    e.confidence = Number(obj['confidence'] ?? 0)
    e.snapshot = String(obj['snapshot'] ?? '')
    return e
  }
}
