import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import '../models/timer_record.dart';
import 'database_service.dart';

enum TimerStatus { idle, running, paused }

/// 倒计时控制器：基于系统时间戳差值计时，杜绝变量累加造成的漂移。
///
/// 核心思路：运行中记录一个「截止时间点」(_deadline)，剩余时长每次实时由
/// `_deadline - now` 计算得出，暂停时把剩余时长快照存下来，恢复时重新计算
/// 新的截止时间点。这样即使出现卡顿或切后台，也不会累积误差。
class TimerController extends ChangeNotifier {
  static const int maxPauses = 3; // 每个任务周期最多暂停次数
  static const int minValidSeconds = 30; // 有效时长下限（秒）

  TimerStatus _status = TimerStatus.idle;
  Duration _target = Duration.zero;
  Duration _remaining = Duration.zero;
  DateTime? _deadline;
  int _pauseCount = 0;
  Timer? _ticker;

  /// 记录保存成功后自增，供统计页刷新监听。
  final ValueNotifier<int> recordRevision = ValueNotifier<int>(0);

  /// 正常倒计时跑完后回调（用于 UI 提示）。
  VoidCallback? onNormalComplete;

  TimerStatus get status => _status;
  Duration get target => _target;
  int get pauseCount => _pauseCount;
  int get remainingPauses => maxPauses - _pauseCount;

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

  void start(Duration target) {
    if (target <= Duration.zero) return;
    _target = target;
    _remaining = target;
    _pauseCount = 0;
    _deadline = DateTime.now().add(target);
    _status = TimerStatus.running;
    _startTicker();
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
    notifyListeners();
  }

  void resume() {
    if (_status != TimerStatus.paused) return;
    if (_remaining <= Duration.zero) return;
    _deadline = DateTime.now().add(_remaining);
    _status = TimerStatus.running;
    _startTicker();
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
      );
    }
    _resetToIdle();
    return valid;
  }

  /// 放弃当前任务：不保存，回到初始状态。
  void abandon() {
    _resetToIdle();
  }

  /// 取消停止，恢复计时。
  void cancelStop() {
    if (_remaining <= Duration.zero) {
      _completeNormally();
    } else {
      resume();
    }
  }

  void reset() {
    _resetToIdle();
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
    Vibration.vibrate(duration: 1500);
    onNormalComplete?.call();
    await _saveRecord(
      targetSeconds: _target.inSeconds,
      effectiveSeconds: _target.inSeconds,
      type: 'normal',
    );
  }

  Future<void> _saveRecord({
    required int targetSeconds,
    required int effectiveSeconds,
    required String type,
  }) async {
    await DatabaseService.instance.insertRecord(TimerRecord(
      targetSeconds: targetSeconds,
      effectiveSeconds: effectiveSeconds,
      completedAtMs: DateTime.now().millisecondsSinceEpoch,
      completionType: type,
    ));
    recordRevision.value++;
  }

  @override
  void dispose() {
    _stopTicker();
    recordRevision.dispose();
    super.dispose();
  }
}
