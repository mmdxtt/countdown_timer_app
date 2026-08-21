import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../services/timer_controller.dart';
import '../utils/feedback.dart';
import '../utils/formatters.dart';

class TimerTab extends StatefulWidget {
  final TimerController controller;
  const TimerTab({super.key, required this.controller});

  @override
  State<TimerTab> createState() => _TimerTabState();
}

class _TimerTabState extends State<TimerTab> with TickerProviderStateMixin {
  static const List<String> _categories = ['学习', '工作', '健身', '休息', '其他'];
  static const Color _accent = Color(0xFF007AFF); // 主色蓝
  static const Color _danger = Color(0xFFFF3B30); // red（暂停 / 停止）
  static const Color _startColor = Color(0xFF00C853); // green（开始）
  static const Color _resumeColor = Color(0xFFFF9500); // orange（继续）
  static const Color _progressColor = Color(0xFF007AFF); // blue（进度环）
  static const Color _trackColor = Color(0xFFE8E8E8); // 进度环轨道
  static const Color _flashColor = Color(0xFFFFE4E0); // 重置闪烁浅红
  static const Color _finishFlashRed = Color(0xFFFFCDD2); // 计时结束淡红

  final TextEditingController _subLabelCtrl = TextEditingController();

  // 选中时长（时 / 分 / 秒），替代原三个数字输入框。
  int _hours = 0;
  int _minutes = 0;
  int _seconds = 0;

  String? _category;
  bool _flashRed = false; // 重置时数字闪烁标记

  // ---- 动画控制器 ----
  late final AnimationController _resetRotateController; // 重置图标旋转
  late final Animation<double> _resetRotation;

  late final AnimationController _mainScaleController; // 主按钮按下缩放
  late final Animation<double> _mainScale;

  late final AnimationController _breatheController; // 计时结束数字呼吸
  late final Animation<double> _breatheOpacity;

  late final AnimationController _flashScreenController; // 计时结束屏幕闪白转淡红
  late final Animation<Color?> _flashColorAnim;

  TimerController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.onNormalComplete = _showCompletedSnack;
    c.addListener(_onControllerChanged);

    // 重置图标旋转 360 度（300ms，Ease-Out）
    _resetRotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _resetRotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _resetRotateController, curve: Curves.easeOut),
    );

    // 主按钮按下缩放：按下 0.92，松开弹性弹回 1.0（100ms，Spring）
    _mainScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _mainScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _mainScaleController,
        curve: Curves.easeOut,
        reverseCurve: Curves.elasticOut, // 松开时弹性回弹
      ),
    );

    // 计时结束数字呼吸（1Hz：500ms 淡出 + 500ms 淡入）
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _breatheOpacity = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    // 计时结束屏幕闪白 → 淡红 → 恢复（400ms）
    _flashScreenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flashColorAnim = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.white, end: _finishFlashRed),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: _finishFlashRed,
          end: _finishFlashRed.withOpacity(0),
        ),
        weight: 50,
      ),
    ]).animate(_flashScreenController);
  }

  @override
  void dispose() {
    c.removeListener(_onControllerChanged);
    _subLabelCtrl.dispose();
    _resetRotateController.dispose();
    _mainScaleController.dispose();
    _breatheController.dispose();
    _flashScreenController.dispose();
    super.dispose();
  }

  /// 消费「再来一次」的预填数据。
  void _onControllerChanged() {
    final target = c.pendingTarget;
    if (target == null) return;
    setState(() {
      _hours = target.inHours;
      _minutes = target.inMinutes % 60;
      _seconds = target.inSeconds % 60;
      _subLabelCtrl.text = c.pendingSubLabel ?? '';
      _category = c.pendingCategory;
    });
    c.clearPending();
  }

  void _showCompletedSnack() {
    if (!mounted) return;
    _snack('倒计时结束，有效时长已保存');
    _playFinishAnimation();
  }

  /// 计时结束动画：屏幕闪白转淡红（400ms）+ 数字呼吸闪烁（1Hz，约 3 秒）。
  void _playFinishAnimation() {
    _flashScreenController.forward(from: 0);
    _breatheController.repeat(reverse: true);
    Future<void>.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      _breatheController.stop();
      _breatheController.value = 0; // 恢复不透明
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Duration _readInput() =>
      Duration(hours: _hours, minutes: _minutes, seconds: _seconds);

  void _onStart() {
    final d = _readInput();
    if (d <= Duration.zero) {
      _snack('请点击数字设置倒计时时长');
      return;
    }
    AppFeedback.click();
    AppFeedback.hapticTap();
    final sub = _subLabelCtrl.text.trim();
    c.start(d, category: _category, subLabel: sub.isEmpty ? null : sub);
  }

  void _onPauseResume() {
    AppFeedback.click();
    AppFeedback.hapticDouble();
    c.togglePause();
  }

  Future<void> _onReset() async {
    AppFeedback.click();
    AppFeedback.hapticLong();
    _resetRotateController.forward(from: 0); // 图标旋转 360 度
    await c.reset();
    if (!mounted) return;
    setState(() {
      _hours = 0;
      _minutes = 0;
      _seconds = 0;
      _category = null;
      _subLabelCtrl.clear();
      _flashRed = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _flashRed = false);
  }

  Future<void> _onStop() async {
    if (!c.isRunning && !c.isPaused) return;
    AppFeedback.click();
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
            onPressed: () {
              AppFeedback.click();
              Navigator.pop(ctx, 'abandon');
            },
            child: const Text('放弃当前任务'),
          ),
          TextButton(
            onPressed: () {
              AppFeedback.click();
              Navigator.pop(ctx, 'early');
            },
            child: const Text('提前完成任务'),
          ),
          FilledButton(
            onPressed: () {
              AppFeedback.click();
              Navigator.pop(ctx, 'cancel');
            },
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

  /// 主按钮按下/松开：切换缩放状态。
  void _setMainPressed(bool pressed) {
    if (pressed) {
      _mainScaleController.forward();
    } else {
      _mainScaleController.reverse();
    }
  }

  /// 弹出底部滚轮选择器（底部滑入滑出 + 蒙层淡入淡出，280ms）。
  Future<void> _showTimePicker() async {
    if (!c.isIdle) return; // 运行/暂停中点击数字不弹选择器
    AppFeedback.click();
    final initial = _readInput();
    final picked = await showGeneralDialog<Duration>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: _TimePickerSheet(initial: initial),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _hours = picked.inHours;
      _minutes = picked.inMinutes % 60;
      _seconds = picked.inSeconds % 60;
    });
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
          body: Stack(
            children: [
              SafeArea(
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
                            if (!idle) _buildStatusInfo(),
                            const SizedBox(height: 16),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: GestureDetector(
                                  onTap: idle ? _showTimePicker : null,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _flashRed
                                          ? _flashColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: FadeTransition(
                                      opacity: _breatheOpacity,
                                      child: _PulsingTimeText(
                                        text: formatHms(display),
                                        fontSize: fontSize,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (idle)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '▼',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFCCCCCC),
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
              // 计时结束：屏幕闪白转淡红 overlay
              AnimatedBuilder(
                animation: _flashScreenController,
                builder: (context, child) {
                  if (_flashScreenController.isDismissed) {
                    return const SizedBox.shrink();
                  }
                  return IgnorePointer(
                    child: Container(color: _flashColorAnim.value),
                  );
                },
              ),
            ],
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
    final progress = c.target.inMilliseconds <= 0
        ? 0.0
        : (c.elapsed.inMilliseconds / c.target.inMilliseconds).clamp(0.0, 1.0);

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
      mainOnPressed = _onPauseResume;
    } else {
      mainLabel = '暂停';
      mainIcon = Icons.pause;
      mainColor = _danger;
      mainOnPressed = canPause ? _onPauseResume : null; // 第 4 次暂停置灰
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 重置：圆形图标按钮（点击旋转 360 度），位于主按钮左侧
          _roundIconButton(
            icon: Icons.refresh,
            tooltip: '重置',
            color: Colors.black54,
            onPressed: _onReset,
            iconTurns: _resetRotation,
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 196,
            height: 196,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  color: _progressColor,
                  backgroundColor: _trackColor,
                ),
                _buildMainButton(
                  label: mainLabel,
                  icon: mainIcon,
                  color: mainColor,
                  onPressed: mainOnPressed,
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // 停止：圆形图标按钮，位于主按钮右侧
          _roundIconButton(
            icon: Icons.stop,
            tooltip: '停止',
            color: _danger,
            onPressed: (running || paused) ? _onStop : null,
          ),
        ],
      ),
    );
  }

  /// 主按钮：按下缩放到 0.92、松开弹性回弹；背景色随状态 200ms 平滑过渡。
  Widget _buildMainButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final effectiveColor = onPressed == null ? color.withOpacity(0.4) : color;
    return GestureDetector(
      onTap: onPressed,
      onTapDown: onPressed == null ? null : (_) => _setMainPressed(true),
      onTapUp: onPressed == null ? null : (_) => _setMainPressed(false),
      onTapCancel: () => _setMainPressed(false),
      child: ScaleTransition(
        scale: _mainScale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 180,
          height: 56,
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    VoidCallback? onPressed,
    Animation<double>? iconTurns,
  }) {
    Widget ic = Icon(icon, size: 22);
    if (iconTurns != null) {
      ic = RotationTransition(turns: iconTurns, child: ic);
    }
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: ic,
        style: IconButton.styleFrom(
          backgroundColor: color.withOpacity(0.08),
          foregroundColor: color,
          fixedSize: const Size(52, 52),
          shape: const CircleBorder(),
          side: BorderSide(color: color.withOpacity(0.35), width: 1),
        ),
      ),
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
        _buildCategoryTabs(idle),
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

  /// 类别标签：文字颜色渐变 + 下划线从旧标签滑动到新标签。
  Widget _buildCategoryTabs(bool idle) {
    final currentCat = idle ? _category : c.category;
    int selectedIndex = -1;
    if (currentCat != null) {
      selectedIndex = _categories.indexOf(currentCat);
    }
    // 选中标签的水平对齐（-1 到 1）
    final x = selectedIndex < 0 ? -1.0 : (2 * selectedIndex - 4) / 5;

    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          Row(
            children: [
              for (final cat in _categories)
                Expanded(child: _categoryLabel(cat, idle)),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 2,
            child: AnimatedAlign(
              alignment: Alignment(x, 0),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: Container(
                width: 22,
                height: 2,
                color: selectedIndex < 0 ? Colors.transparent : _accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 底部类别标签：纯文字、无背景，文字颜色 200ms 渐变。
  Widget _categoryLabel(String label, bool idle) {
    final bool selected = idle ? (_category == label) : (c.category == label);
    final color = selected ? _accent : const Color(0xFF999999);
    return InkWell(
      onTap: idle ? () => _onCategoryTap(label) : null,
      child: SizedBox(
        height: 40,
        child: Align(
          alignment: Alignment.center,
          child: TweenAnimationBuilder<Color>(
            tween: Tween(end: color),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            builder: (context, value, child) => Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: value,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onCategoryTap(String label) {
    AppFeedback.click();
    setState(() {
      _category = (_category == label) ? null : label;
      _subLabelCtrl.clear();
    });
  }
}

/// 计时数字：每秒变化时缩放脉冲（瞬间 1.08x，150ms 弹性回弹）。
class _PulsingTimeText extends StatefulWidget {
  final String text;
  final double fontSize;
  const _PulsingTimeText({required this.text, required this.fontSize});

  @override
  State<_PulsingTimeText> createState() => _PulsingTimeTextState();
}

class _PulsingTimeTextState extends State<_PulsingTimeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // 初始停在 1.0（value=1），触发脉冲时 forward(from:0) 瞬间跳到 1.08 再弹回。
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: 1.0,
    );
    _scale = Tween<double>(begin: 1.08, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(covariant _PulsingTimeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.forward(from: 0); // 数字变化 → 脉冲
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Text(
        widget.text,
        maxLines: 1,
        style: TextStyle(
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: 2,
          color: Colors.black87,
        ),
      ),
    );
  }
}

/// 底部弹出的滚轮选择器（时 / 分 / 秒三列，iOS 闹钟样式）。
class _TimePickerSheet extends StatefulWidget {
  final Duration initial;
  const _TimePickerSheet({required this.initial});

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  static const Color _blue = Color(0xFF007AFF);
  late int _hours;
  late int _minutes;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _hours = widget.initial.inHours.clamp(0, 23);
    _minutes = widget.initial.inMinutes % 60;
    _seconds = widget.initial.inSeconds % 60;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    AppFeedback.click();
                    Navigator.pop(context);
                  },
                  child: const Text('取消', style: TextStyle(color: Colors.black54)),
                ),
                TextButton(
                  onPressed: () {
                    AppFeedback.click();
                    Navigator.pop(
                      context,
                      Duration(hours: _hours, minutes: _minutes, seconds: _seconds),
                    );
                  },
                  child: const Text(
                    '确认',
                    style: TextStyle(color: _blue, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _WheelColumn(
                    itemCount: 24,
                    selectedIndex: _hours,
                    unit: '小时',
                    onChanged: (v) => setState(() => _hours = v),
                  ),
                ),
                Expanded(
                  child: _WheelColumn(
                    itemCount: 60,
                    selectedIndex: _minutes,
                    unit: '分钟',
                    onChanged: (v) => setState(() => _minutes = v),
                  ),
                ),
                Expanded(
                  child: _WheelColumn(
                    itemCount: 60,
                    selectedIndex: _seconds,
                    unit: '秒',
                    onChanged: (v) => setState(() => _seconds = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// 单列滚轮：数字列表 + 下方单位文字，选中行主色蓝高亮、上下行深灰。
class _WheelColumn extends StatefulWidget {
  final int itemCount;
  final int selectedIndex;
  final String unit;
  final ValueChanged<int> onChanged;
  const _WheelColumn({
    required this.itemCount,
    required this.selectedIndex,
    required this.unit,
    required this.onChanged,
  });

  @override
  State<_WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<_WheelColumn> {
  static const Color _selected = Color(0xFF007AFF); // 选中行主色蓝
  static const Color _dim = Color(0xFF555555); // 上下行深灰
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: widget.selectedIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 180,
          child: ListWheelScrollView.useDelegate(
            controller: _controller,
            itemExtent: 36,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: widget.onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.itemCount,
              builder: (context, index) {
                final selected = index == widget.selectedIndex;
                return Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? _selected : _dim,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.unit,
          style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
        ),
      ],
    );
  }
}
