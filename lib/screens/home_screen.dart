import 'package:flutter/material.dart';

import '../services/timer_controller.dart';
import 'stats_tab.dart';
import 'timer_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TimerController _controller = TimerController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // 启动时尝试恢复「进行中」的任务（若 App 被系统杀掉/重启）
    _controller.restore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToTimer() => setState(() => _index = 0);

  /// 单个 Tab 容器：保活 + iOS 风格水平滑动 + 轻微淡入淡出。
  /// 选中 Tab 居中，未选中的 Tab 按 index 关系滑到屏幕左/右外（各 300ms）。
  Widget _buildTab(int idx, Widget child) {
    final current = _index;
    double x;
    double opacity;
    if (current == idx) {
      x = 0;
      opacity = 1.0;
    } else if (idx < current) {
      x = -1;
      opacity = 0.7;
    } else {
      x = 1;
      opacity = 0.7;
    }
    return IgnorePointer(
      ignoring: current != idx,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        child: AnimatedAlign(
          alignment: Alignment(x, 0),
          widthFactor: 1,
          heightFactor: 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Stack + AnimatedOpacity 交叉淡化：两个 Tab 都保活（计时不中断），
      // 切换时各 150ms 淡入/淡出，重叠执行。
      body: Stack(
        children: [
          _buildTab(
            0,
            TimerTab(controller: _controller),
          ),
          _buildTab(
            1,
            StatsTab(controller: _controller, onGoToTimer: _goToTimer),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(child: _tabItem('倒计时任务', 0)),
              Container(width: 1, height: 20, color: const Color(0xFFEEEEEE)),
              Expanded(child: _tabItem('数据统计', 1)),
            ],
          ),
        ),
      ),
    );
  }

  /// 底部纯文字 Tab 项：选中主色蓝 + 加粗，未选中浅灰。
  Widget _tabItem(String label, int idx) {
    final selected = _index == idx;
    return InkWell(
      onTap: () => setState(() => _index = idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? const Color(0xFF007AFF) : const Color(0xFF999999),
          ),
        ),
      ),
    );
  }
}
