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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: '倒计时任务',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '数据统计',
          ),
        ],
      ),
    );
  }
}
