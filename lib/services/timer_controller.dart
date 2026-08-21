import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/timer_record.dart';
import '../utils/feedback.dart';
import 'database_service.dart';

enum TimerStatus { idle, running, paused }

/// 倒计时控制器：基于系统时间戳差值计时，杜绝变量累加造成的漂移。
///
/// 核心思路：运行中记录一个「截止时间点」(_deadline)，剩余时长每次实时由
/// `_deadline - now` 计算得出，暂停时把剩余时长快照存下来，恢复时重新计算
/// 新的截止时间点。这样即使出现卡顿或切后台，也不会累积误差。
///
/// 此外支持：进行中任务持久化（切后台/被杀进程后可恢复）、一级+二级标签、
/// 「再来一次」预填。
class TimerController extends ChangeNotifier {
  static const int maxPauses = 3; // 每个任务周期最多暂停次数
  static const int minValidSeconds = 30; // 有效时长下限（秒）

  TimerStatus _status = TimerStatus.idle;
  Duration _target = Duration.zero;
  Duration _remaining = Duration.zero;
  DateTime? _deadline;
  int _pauseCount = 0;
  String? _category;
  String? _subLabel;
  Timer? _ticker;

  /// 记录保存成功后自增，供统计页刷新监听。
  final ValueNotifier<int> recordRevision = ValueNotifier<int>(0);

  /// 正常倒计时跑完后回调（用于 UI 提示）。
  VoidCallback? onNormalComplete;

  /// 「再来一次」的预填数据（由统计页写入，倒计时页消费后清空）。
  Duration? pendingTarget;
  String? pendingCategory;
  String? pendingSubLabel;

  TimerStatus get status => _status;
  Duration get target => _target;
  int get pauseCount => _pauseCount;
  int get remainingPauses => maxPauses - _pauseCount;
  String? get category => _category;
  String? get subLabel => _subLabel;

  bool get isIdle => _status == TimerStatus.idle;
  bool get isRunning => _status == TimerStatus.running;
  bool get isPaused => _status == TimerStatus.paused;

  /// 剩余时长：运行中实时按时间戳计算，其余状态返回快照值。
  Duration get remaining {
    if (_status == TimerStatus.running && _deadline != null) {
      final diff = _deadline!.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    }
    return _remaining;
  }

  /// 已实际计时的有效时长（自动扣除暂停时间）。
  Duration get elapsed {
    final e = _target - remaining;
    return e.isNegative ? Duration.zero : e;
  }

  void start(Duration target, {String? category, String? subLabel}) {
    if (target <= Duration.zero) return;
    _target = target;
    _remaining = target;
    _pauseCount = 0;
    _category = category;
    _subLabel = subLabel;
    _deadline = DateTime.now().add(target);
    _status = TimerStatus.running;
    _startTicker();
    _persistActive();
    notifyListeners();
  }

  void togglePause() {
    if (_status == TimerStatus.running) {
      pause();
    } else if (_status == TimerStatus.paused) {
      resume();
    }
  }

  void pause() {
    if (_status != TimerStatus.running) return;
    if (_pauseCount >= maxPauses) return; // 超过上限，禁止再次暂停
    _remaining = remaining; // 快照剩余时长
    _pauseCount++;
    _status = TimerStatus.paused;
    _stopTicker();
    _persistActive();
    notifyListeners();
  }

  void resume() {
    if (_status != TimerStatus.paused) return;
    if (_remaining <= Duration.zero) return;
    _deadline = DateTime.now().add(_remaining);
    _status = TimerStatus.running;
    _startTicker();
    _persistActive();
    notifyListeners();
  }

  /// 用户点击【停止】，冻结计时等待弹窗选择。
  void requestStop() {
    if (_status == TimerStatus.running) {
      _remaining = remaining;
    }
    if (_status == TimerStatus.running || _status == TimerStatus.paused) {
      _status = TimerStatus.paused;
      _stopTicker();
      _persistActive();
      notifyListeners();
    }
  }

  /// 提前完成：有效时长 >= 30 秒才入库，返回是否已保存。
  Future<bool> completeEarly() async {
    final seconds = elapsed.inSeconds;
    final valid = seconds >= minValidSeconds;
    if (valid) {
      await _saveRecord(
        targetSeconds: _target.inSeconds,
        effectiveSeconds: seconds,
        type: 'early',
        category: _category,
        subLabel: _subLabel,
      );
    }
    _resetToIdle();
    await _clearActive();
    return valid;
  }

  /// 放弃当前任务：不保存，回到初始状态。
  Future<void> abandon() async {
    _resetToIdle();
    await _clearActive();
  }

  /// 取消停止，恢复计时。
  void cancelStop() {
    if (_remaining <= Duration.zero) {
      _completeNormally();
    } else {
      resume();
    }
  }

  Future<void> reset() async {
    _resetToIdle();
    await _clearActive();
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_status == TimerStatus.running && remaining <= Duration.zero) {
        _completeNormally();
      } else {
        notifyListeners();
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _resetToIdle() {
    _stopTicker();
    _status = TimerStatus.idle;
    _remaining = _target;
    _deadline = null;
    _pauseCount = 0;
    _category = null;
    _subLabel = null;
    notifyListeners();
  }

  /// 倒计时跑完：震动提醒 + 自动保存有效时长。
  Future<void> _completeNormally() async {
    _remaining = Duration.zero;
    _stopTicker();
    _deadline = null;
    _status = TimerStatus.idle;
    _pauseCount = 0;
    notifyListeners();
    // 归零提醒：连续震动三次 + 结束铃声（同步触发）
    AppFeedback.hapticTriple();
    AppFeedback.alarm();
    onNormalComplete?.call();
    await _saveRecord(
      targetSeconds: _target.inSeconds,
      effectiveSeconds: _target.inSeconds,
      type: 'normal',
      category: _category,
      subLabel: _subLabel,
    );
    _category = null;
    _subLabel = null;
    await _clearActive();
  }

  Future<void> _saveRecord({
    required int targetSeconds,
    required int effectiveSeconds,
    required String type,
    String? category,
    String? subLabel,
  }) async {
    await DatabaseService.instance.insertRecord(TimerRecord(
      targetSeconds: targetSeconds,
      effectiveSeconds: effectiveSeconds,
      completedAtMs: DateTime.now().millisecondsSinceEpoch,
      completionType: type,
      category: category,
      subLabel: subLabel,
    ));
    recordRevision.value++;
  }

  // ---- 进行中任务持久化 / 恢复 ----

  /// 把当前进行中任务写入数据库（fire-and-forget）。
  void _persistActive() {
    final task = ActiveTask(
      status: _status == TimerStatus.running ? 'running' : 'paused',
      targetSeconds: _target.inSeconds,
      deadlineMs: _deadline?.millisecondsSinceEpoch,
      remainingMs: _remaining.inMilliseconds,
      pauseCount: _pauseCount,
      category: _category,
      subLabel: _subLabel,
    );
    DatabaseService.instance.saveActiveTask(task);
  }

  Future<void> _clearActive() async {
    await DatabaseService.instance.clearActiveTask();
  }

  /// 启动时调用：读回未完成的任务并恢复倒计时。
  ///
  /// - 暂停中 → 恢复暂停状态，显示剩余时长。
  /// - 运行中且未过期 → 按截止时刻恢复，继续跑。
  /// - 运行中但已过期 → 自动补记为「正常完成」入库。
  Future<void> restore() async {
    final active = await DatabaseService.instance.loadActiveTask();
    if (active == null) return;
    _target = Duration(seconds: active.targetSeconds);
    _pauseCount = active.pauseCount;
    _category = active.category;
    _subLabel = active.subLabel;

    if (active.status == 'paused') {
      _remaining = Duration(milliseconds: active.remainingMs ?? 0);
      _status = TimerStatus.paused;
      notifyListeners();
      return;
    }

    final deadlineMs = active.deadlineMs;
    if (deadlineMs == null) {
      _resetToIdle();
      await _clearActive();
      return;
    }
    final deadline = DateTime.fromMillisecondsSinceEpoch(deadlineMs);
    final remaining = deadline.difference(DateTime.now());
    if (remaining > Duration.zero) {
      _deadline = deadline;
      _status = TimerStatus.running;
      _startTicker();
      notifyListeners();
    } else {
      // 后台期间已自然跑完 → 自动补记完成
      await _clearActive();
      await _saveRecord(
        targetSeconds: _target.inSeconds,
        effectiveSeconds: _target.inSeconds,
        type: 'normal',
        category: _category,
        subLabel: _subLabel,
      );
      _resetToIdle();
    }
  }

  // ---- 再来一次 ----

  void requestRestart({
    required Duration target,
    String? category,
    String? subLabel,
  }) {
    pendingTarget = target;
    pendingCategory = category;
    pendingSubLabel = subLabel;
    notifyListeners();
  }

  void clearPending() {
    pendingTarget = null;
    pendingCategory = null;
    pendingSubLabel = null;
  }

  @override
  void dispose() {
    _stopTicker();
    recordRevision.dispose();
    super.dispose();
  }
}
