/// 一条已保存的倒计时记录。
class TimerRecord {
  final int? id;
  final int targetSeconds; // 目标时长（秒）
  final int effectiveSeconds; // 实际有效计时时长（秒，已扣除暂停）
  final int completedAtMs; // 完成时间（毫秒时间戳）
  final String completionType; // 'normal' 正常完成 | 'early' 提前完成

  const TimerRecord({
    this.id,
    required this.targetSeconds,
    required this.effectiveSeconds,
    required this.completedAtMs,
    required this.completionType,
  });

  DateTime get completedAt => DateTime.fromMillisecondsSinceEpoch(completedAtMs);

  bool get isNormal => completionType == 'normal';

  Map<String, dynamic> toMap() => {
        'id': id,
        'target_seconds': targetSeconds,
        'effective_seconds': effectiveSeconds,
        'completed_at_ms': completedAtMs,
        'completion_type': completionType,
      };

  factory TimerRecord.fromMap(Map<String, dynamic> map) => TimerRecord(
        id: map['id'] as int?,
        targetSeconds: map['target_seconds'] as int,
        effectiveSeconds: map['effective_seconds'] as int,
        completedAtMs: map['completed_at_ms'] as int,
        completionType: map['completion_type'] as String,
      );
}
