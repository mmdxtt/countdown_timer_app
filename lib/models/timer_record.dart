/// 一条已保存的倒计时记录。
class TimerRecord {
  final int? id;
  final int targetSeconds; // 目标时长（秒）
  final int effectiveSeconds; // 实际有效计时时长（秒，已扣除暂停）
  final int completedAtMs; // 完成时间（毫秒时间戳）
  final String completionType; // 'normal' 正常完成 | 'early' 提前完成
  final String? category; // 一级标签，如「学习」「健身」
  final String? subLabel; // 二级自定义标签，如「数学」

  const TimerRecord({
    this.id,
    required this.targetSeconds,
    required this.effectiveSeconds,
    required this.completedAtMs,
    required this.completionType,
    this.category,
    this.subLabel,
  });

  DateTime get completedAt => DateTime.fromMillisecondsSinceEpoch(completedAtMs);

  bool get isNormal => completionType == 'normal';

  /// 组合标签文本，如「学习·数学」；无标签返回 null。
  String? get labelText {
    final cat = category;
    if (cat == null || cat.isEmpty) return null;
    final sub = subLabel;
    if (sub == null || sub.isEmpty) return cat;
    return '$cat·$sub';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'target_seconds': targetSeconds,
        'effective_seconds': effectiveSeconds,
        'completed_at_ms': completedAtMs,
        'completion_type': completionType,
        'category': category,
        'sub_label': subLabel,
      };

  factory TimerRecord.fromMap(Map<String, dynamic> map) => TimerRecord(
        id: map['id'] as int?,
        targetSeconds: map['target_seconds'] as int,
        effectiveSeconds: map['effective_seconds'] as int,
        completedAtMs: map['completed_at_ms'] as int,
        completionType: map['completion_type'] as String,
        category: map['category'] as String?,
        subLabel: map['sub_label'] as String?,
      );
}

/// 一个「进行中」的任务，用于持久化 + 重启恢复。
///
/// 数据库中以单行（id = 1）形式保存，启动时读回。
class ActiveTask {
  final String status; // 'running' 运行中 | 'paused' 已暂停
  final int targetSeconds;
  final int? deadlineMs; // 运行中：截止时刻时间戳
  final int? remainingMs; // 已暂停：剩余时长快照
  final int pauseCount;
  final String? category;
  final String? subLabel;

  const ActiveTask({
    required this.status,
    required this.targetSeconds,
    this.deadlineMs,
    this.remainingMs,
    required this.pauseCount,
    this.category,
    this.subLabel,
  });

  Map<String, dynamic> toMap() => {
        'id': 1,
        'status': status,
        'target_seconds': targetSeconds,
        'deadline_ms': deadlineMs,
        'remaining_ms': remainingMs,
        'pause_count': pauseCount,
        'category': category,
        'sub_label': subLabel,
      };

  factory ActiveTask.fromMap(Map<String, dynamic> map) => ActiveTask(
        status: map['status'] as String,
        targetSeconds: map['target_seconds'] as int,
        deadlineMs: map['deadline_ms'] as int?,
        remainingMs: map['remaining_ms'] as int?,
        pauseCount: map['pause_count'] as int,
        category: map['category'] as String?,
        subLabel: map['sub_label'] as String?,
      );
}
