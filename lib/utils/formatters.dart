String _two(int n) => n.toString().padLeft(2, '0');

/// 格式化为 HH:MM:SS（小时可超过 99，用于大号倒计时显示）。
String formatHms(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  return '${_two(h)}:${_two(m)}:${_two(sec)}';
}

/// 格式化为中文友好形式：X小时Y分Z秒。
String formatDurationCn(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  if (h > 0) return '$h小时$m分$sec秒';
  if (m > 0) return '$m分$sec秒';
  return '$sec秒';
}

/// 2026-08-14 16:45
String formatDateTime(DateTime dt) =>
    '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';

/// 2026-08-14
String formatDate(DateTime dt) =>
    '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
