import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/timer_controller.dart';
import '../utils/formatters.dart';

class TimerTab extends StatefulWidget {
  final TimerController controller;
  const TimerTab({super.key, required this.controller});

  @override
  State<TimerTab> createState() => _TimerTabState();
}

class _TimerTabState extends State<TimerTab> {
  final TextEditingController _hourCtrl = TextEditingController();
  final TextEditingController _minuteCtrl = TextEditingController();
  final TextEditingController _secondCtrl = TextEditingController();

  TimerController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.onNormalComplete = _showCompletedSnack;
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _secondCtrl.dispose();
    super.dispose();
  }

  void _showCompletedSnack() {
    if (!mounted) return;
    _snack('倒计时结束，有效时长已保存');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Duration _readInput() {
    final h = int.tryParse(_hourCtrl.text) ?? 0;
    final m = int.tryParse(_minuteCtrl.text) ?? 0;
    final s = int.tryParse(_secondCtrl.text) ?? 0;
    return Duration(hours: h, minutes: m, seconds: s);
  }

  void _onStart() {
    final d = _readInput();
    if (d <= Duration.zero) {
      _snack('请输入大于 0 的倒计时时长');
      return;
    }
    c.start(d);
  }

  Future<void> _onReset() async {
    if (c.isRunning || c.isPaused) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('清空当前任务'),
          content: const Text('确定要清空当前倒计时任务吗？本次计时将不会被保存。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      _hourCtrl.clear();
      _minuteCtrl.clear();
      _secondCtrl.clear();
    });
    c.reset();
  }

  Future<void> _onStop() async {
    if (!c.isRunning && !c.isPaused) return;
    c.requestStop();
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('停止计时'),
        content: const Text('请选择如何处理本次计时：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'abandon'),
            child: const Text('放弃当前任务'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'early'),
            child: const Text('提前完成任务'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'abandon':
        c.abandon();
        break;
      case 'early':
        final saved = await c.completeEarly();
        if (!mounted) return;
        _snack(saved ? '已保存本次有效时长' : '有效计时不足 30 秒，本次不计入统计');
        break;
      case 'cancel':
      default:
        c.cancelStop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final idle = c.isIdle;
        final running = c.isRunning;
        final paused = c.isPaused;
        final display = idle ? _readInput() : c.remaining;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatHms(display),
                    style: const TextStyle(
                      fontSize: 68,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _statusText(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '剩余暂停次数：${c.remainingPauses} / ${TimerController.maxPauses}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.remainingPauses == 0
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                const SizedBox(height: 28),
                if (idle) _buildInput() else _buildRunningInfo(),
                const Spacer(),
                _buildButtons(idle, running, paused),
                const SizedBox(height: 14),
                Text(
                  '提示：安卓切后台后计时可能被系统暂停，建议保持前台运行。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusText() {
    switch (c.status) {
      case TimerStatus.idle:
        return '未开始';
      case TimerStatus.running:
        return '倒计时进行中';
      case TimerStatus.paused:
        return '已暂停';
    }
  }

  Widget _buildInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _numberField(_hourCtrl, '时', 3),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ),
        _numberField(_minuteCtrl, '分', 2),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ),
        _numberField(_secondCtrl, '秒', 2),
      ],
    );
  }

  Widget _numberField(TextEditingController ctrl, String label, int maxLength) {
    return SizedBox(
      width: 78,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: maxLength,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRunningInfo() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('目标时长', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  formatHms(c.target),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('已计时', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  formatHms(c.elapsed),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons(bool idle, bool running, bool paused) {
    final scheme = Theme.of(context).colorScheme;
    final canPause = running && c.pauseCount < TimerController.maxPauses;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _btn('开始', Icons.play_arrow,
                  onPressed: idle ? _onStart : null, filled: true),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _btn(
                paused ? '继续' : '暂停',
                paused ? Icons.play_arrow : Icons.pause,
                onPressed: (paused || canPause) ? c.togglePause : null,
                filled: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _btn(
                '停止',
                Icons.stop,
                onPressed: (running || paused) ? _onStop : null,
                filled: true,
                color: scheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _btn('重置', Icons.refresh, onPressed: _onReset),
      ],
    );
  }

  Widget _btn(
    String label,
    IconData icon, {
    VoidCallback? onPressed,
    bool filled = false,
    Color? color,
  }) {
    final EdgeInsets padding = const EdgeInsets.symmetric(vertical: 14);
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: padding,
          backgroundColor: color,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(padding: padding),
    );
  }
}
