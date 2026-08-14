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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack 保证切换 Tab 时倒计时状态不丢失、计时不中断
      body: IndexedStack(
        index: _index,
        children: [
          TimerTab(controller: _controller),
          StatsTab(controller: _controller),
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
