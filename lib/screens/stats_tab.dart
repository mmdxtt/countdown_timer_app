import 'package:flutter/material.dart';

import '../models/timer_record.dart';
import '../services/database_service.dart';
import '../services/timer_controller.dart';
import '../utils/formatters.dart';

enum FilterMode { today, week, month, custom }

class StatsTab extends StatefulWidget {
  final TimerController controller;
  final VoidCallback? onGoToTimer; // 「再来一次」时切回倒计时页
  const StatsTab({super.key, required this.controller, this.onGoToTimer});

  @override
  State<StatsTab> createState() => StatsTabState();
}

class StatsTabState extends State<StatsTab> {
  FilterMode _mode = FilterMode.today;
  DateTimeRange? _customRange;
  List<TimerRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.controller.recordRevision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.controller.recordRevision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final range = _range();
    if (range == null) {
      if (mounted) {
        setState(() {
          _records = [];
          _loading = false;
        });
      }
      return;
    }
    final list =
        await DatabaseService.instance.getRecordsBetween(range.start, range.end);
    if (!mounted) return;
    setState(() {
      _records = list;
      _loading = false;
    });
  }

  DateTimeRange? _range() {
    final now = DateTime.now();
    switch (_mode) {
      case FilterMode.today:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: now,
        );
      case FilterMode.week:
        // 周一为一周起点
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: start, end: now);
      case FilterMode.month:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case FilterMode.custom:
        final r = _customRange;
        if (r == null) return null;
        final start = DateTime(r.start.year, r.start.month, r.start.day);
        final end = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
    }
  }

  Duration get _total => _records.fold(
        Duration.zero,
        (sum, r) => sum + Duration(seconds: r.effectiveSeconds),
      );

  /// 按「一级标签·二级标签」聚合的有效时长，按总时长降序。
  List<MapEntry<String, Duration>> _categoryBreakdown() {
    final map = <String, Duration>{};
    for (final r in _records) {
      final cat = r.category;
      final sub = r.subLabel;
      final key = (cat == null || cat.isEmpty)
          ? '未分类'
          : ((sub == null || sub.isEmpty) ? cat : '$cat·$sub');
      map[key] = (map[key] ?? Duration.zero) + Duration(seconds: r.effectiveSeconds);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  Future<void> _selectFilter(FilterMode m) async {
    if (m == FilterMode.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: _customRange,
        helpText: '选择统计时间范围',
      );
      if (picked == null) return;
      _customRange = picked;
    }
    setState(() => _mode = m);
    _reload();
  }

  /// 「再来一次」：预填并切回倒计时页。
  void _restart(TimerRecord r) {
    if (!widget.controller.isIdle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先完成或重置当前任务，再开始新的计时'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    widget.controller.requestRestart(
      target: Duration(seconds: r.targetSeconds),
      category: r.category,
      subLabel: r.subLabel,
    );
    widget.onGoToTimer?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('数据统计', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _buildFilterChips(),
            if (_mode == FilterMode.custom) _buildCustomRange(),
            const SizedBox(height: 16),
            _buildSummaryCard(),
            const SizedBox(height: 12),
            _buildCategoryBreakdown(),
            const SizedBox(height: 12),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    const items = [
      (FilterMode.today, '今日'),
      (FilterMode.week, '本周'),
      (FilterMode.month, '本月'),
      (FilterMode.custom, '自定义'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final (mode, label) in items)
          ChoiceChip(
            label: Text(label),
            selected: _mode == mode,
            onSelected: (_) => _selectFilter(mode),
          ),
      ],
    );
  }

  Widget _buildCustomRange() {
    final r = _customRange;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: () => _selectFilter(FilterMode.custom),
        icon: const Icon(Icons.date_range, size: 18),
        label: Text(
          r == null ? '选择开始与结束日期' : '${formatDate(r.start)}  ~  ${formatDate(r.end)}',
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('总有效时长', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              formatDurationCn(_total),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '共 ${_records.length} 条记录',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final scheme = Theme.of(context).colorScheme;
    final entries = _categoryBreakdown();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('分类统计', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.key, style: const TextStyle(fontSize: 14)),
                    ),
                    Text(
                      formatDurationCn(e.value),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('暂无记录', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _records.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = _records[i];
        final label = r.labelText;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: CircleAvatar(
            radius: 18,
            child: Icon(r.isNormal ? Icons.check : Icons.flag, size: 18),
          ),
          title: Row(
            children: [
              Expanded(child: Text(formatDateTime(r.completedAt))),
              if (label != null) _labelChip(label),
            ],
          ),
          subtitle: Text(
            '目标 ${formatHms(Duration(seconds: r.targetSeconds))} · '
            '${r.isNormal ? '正常完成' : '提前完成'}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatDurationCn(Duration(seconds: r.effectiveSeconds)),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.replay, size: 20),
                tooltip: '再来一次',
                onPressed: () => _restart(r),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _labelChip(String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer),
      ),
    );
  }
}
