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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack 保证切换 Tab 时倒计时状态不丢失、计时不中断
      body: IndexedStack(
        index: _index,
        children: [
          TimerTab(controller: _controller),
          StatsTab(controller: _controller, onGoToTimer: _goToTimer),
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
