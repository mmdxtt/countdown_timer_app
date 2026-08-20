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
  static const List<String> _categories = ['学习', '工作', '健身', '休息', '其他'];
  static const Color _accent = Color(0xFF3F51B5); // indigo
  static const Color _danger = Color(0xFFFF3B30); // red（暂停 / 停止）
  static const Color _startColor = Color(0xFF00C853); // green（开始）
  static const Color _resumeColor = Color(0xFFFF9500); // orange（继续）

  final TextEditingController _hourCtrl = TextEditingController();
  final TextEditingController _minuteCtrl = TextEditingController();
  final TextEditingController _secondCtrl = TextEditingController();
  final TextEditingController _subLabelCtrl = TextEditingController();

  String? _category;

  TimerController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.onNormalComplete = _showCompletedSnack;
    c.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    c.removeListener(_onControllerChanged);
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _secondCtrl.dispose();
    _subLabelCtrl.dispose();
    super.dispose();
  }

  /// 消费「再来一次」的预填数据。
  void _onControllerChanged() {
    final target = c.pendingTarget;
    if (target == null) return;
    _hourCtrl.text = target.inHours > 0 ? '${target.inHours}' : '';
    _minuteCtrl.text = target.inMinutes % 60 > 0 ? '${target.inMinutes % 60}' : '';
    _secondCtrl.text = target.inSeconds % 60 > 0 ? '${target.inSeconds % 60}' : '';
    _subLabelCtrl.text = c.pendingSubLabel ?? '';
    _category = c.pendingCategory;
    c.clearPending();
    setState(() {});
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
    final sub = _subLabelCtrl.text.trim();
    c.start(d, category: _category, subLabel: sub.isEmpty ? null : sub);
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
      _subLabelCtrl.clear();
      _category = null;
    });
    await c.reset();
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
        await c.abandon();
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
        final screenWidth = MediaQuery.of(context).size.width;
        final fontSize = (screenWidth * 0.18).clamp(80.0, 120.0);

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 顶部：App 名称
                  const Text(
                    '倒计时',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  // 中间：数字 + 按钮（垂直居中）
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (idle) _buildInput() else _buildStatusInfo(),
                        const SizedBox(height: 16),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatHms(display),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              letterSpacing: 2,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildButtons(idle, running, paused),
                      ],
                    ),
                  ),
                  // 底部：二级输入 + 类别标签 + 提示图标
                  _buildBottomArea(idle),
                ],
              ),
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
          child: Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black54)),
        ),
        _numberField(_minuteCtrl, '分', 2),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black54)),
        ),
        _numberField(_secondCtrl, '秒', 2),
      ],
    );
  }

  Widget _numberField(TextEditingController ctrl, String label, int maxLength) {
    return SizedBox(
      width: 72,
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
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildStatusInfo() {
    return Column(
      children: [
        Text(
          _statusText(),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _accent),
        ),
        const SizedBox(height: 6),
        Text(
          '目标 ${formatHms(c.target)} · 已计时 ${formatHms(c.elapsed)}',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          '剩余暂停 ${c.remainingPauses} / ${TimerController.maxPauses}',
          style: TextStyle(
            fontSize: 13,
            color: c.remainingPauses == 0 ? _danger : Colors.grey.shade600,
          ),
        ),
        if (c.category != null) ...[
          const SizedBox(height: 4),
          Text(
            (c.subLabel == null || c.subLabel!.isEmpty)
                ? c.category!
                : '${c.category}·${c.subLabel}',
            style: const TextStyle(fontSize: 13, color: _accent),
          ),
        ],
      ],
    );
  }

  Widget _buildButtons(bool idle, bool running, bool paused) {
    final canPause = running && c.pauseCount < TimerController.maxPauses;

    String mainLabel;
    IconData mainIcon;
    Color mainColor;
    VoidCallback? mainOnPressed;
    if (idle) {
      mainLabel = '开始';
      mainIcon = Icons.play_arrow;
      mainColor = _startColor;
      mainOnPressed = _onStart;
    } else if (paused) {
      mainLabel = '继续';
      mainIcon = Icons.play_arrow;
      mainColor = _resumeColor;
      mainOnPressed = c.togglePause;
    } else {
      mainLabel = '暂停';
      mainIcon = Icons.pause;
      mainColor = _danger;
      mainOnPressed = canPause ? c.togglePause : null; // 第 4 次暂停置灰
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 180,
          height: 56,
          child: FilledButton.icon(
            onPressed: mainOnPressed,
            icon: Icon(mainIcon, size: 22),
            label: Text(mainLabel),
            style: FilledButton.styleFrom(
              backgroundColor: mainColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (running || paused) ? _onStop : null,
                icon: const Icon(Icons.stop, size: 18),
                label: const Text('停止'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _danger,
                  side: const BorderSide(color: _danger, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _onReset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重置'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black54,
                  side: const BorderSide(color: Colors.black26, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomArea(bool idle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (idle && _category != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _subLabelCtrl,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: Colors.black87),
              decoration: const InputDecoration(
                labelText: '二级标签（可选）',
                hintText: '如：数学',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.label_outline, size: 18),
              ),
            ),
          ),
        Row(
          children: [
            for (final cat in _categories)
              Expanded(child: _categoryLabel(cat, idle)),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Tooltip(
            message: '安卓切后台后计时可能被系统暂停，建议保持前台运行',
            child: Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
          ),
        ),
      ],
    );
  }

  /// 底部类别标签：纯文字、无背景，选中时下划线高亮。
  Widget _categoryLabel(String label, bool idle) {
    final bool selected = idle ? (_category == label) : (c.category == label);
    return InkWell(
      onTap: idle ? () => _onCategoryTap(label) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? _accent : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 2,
              width: 22,
              color: selected ? _accent : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  void _onCategoryTap(String label) {
    setState(() {
      _category = (_category == label) ? null : label;
      _subLabelCtrl.clear();
    });
  }
}
