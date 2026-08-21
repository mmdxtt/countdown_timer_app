import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// 全局交互反馈：震动（vibration 包）+ 系统提示音（内置 SystemSound）。
///
/// - 震动仅 Android 生效（已声明 VIBRATE 权限），其他平台静默降级；
/// - 声音用 Flutter 内置的 SystemSound（系统默认音效），零第三方依赖。
class Feedback {
  Feedback._();

  /// 短震一次（10ms）：点击「开始」。
  static void hapticTap() {
    unawaited(Vibration.vibrate(duration: 10));
  }

  /// 双震（10ms ×2，间隔 50ms）：点击「暂停 / 继续」。
  static void hapticDouble() {
    unawaited(Vibration.vibrate(pattern: const [0, 10, 50, 10]));
  }

  /// 长震一次（50ms）：点击「重置」。
  static void hapticLong() {
    unawaited(Vibration.vibrate(duration: 50));
  }

  /// 连续震动三次（15ms ×3，间隔 100ms）：倒计时归零。
  static void hapticTriple() {
    unawaited(Vibration.vibrate(pattern: const [0, 15, 100, 15, 100, 15]));
  }

  /// 极轻按键音：系统默认点击音。
  static void click() {
    unawaited(SystemSound.play(SystemSoundType.click));
  }

  /// 结束铃声：系统提示音重复 3 次（与震动同步触发，fire-and-forget）。
  static void alarm() {
    unawaited(_alarmLoop(3));
  }

  static Future<void> _alarmLoop(int times) async {
    for (int i = 0; i < times; i++) {
      unawaited(SystemSound.play(SystemSoundType.alert));
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
  }
}
