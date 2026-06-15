class BusinessHoursStatus {
  final bool? isOpen;
  final String? todayLabel;

  const BusinessHoursStatus({
    required this.isOpen,
    required this.todayLabel,
  });

  bool get hasData => isOpen != null || todayLabel != null;
}

class BusinessHoursService {
  static BusinessHoursStatus status(
    Map<String, dynamic>? workingHours, {
    DateTime? now,
  }) {
    final label = todayHoursLabel(workingHours, now: now);
    return BusinessHoursStatus(
      isOpen: isOpenNowFromTodayLabel(label, now: now),
      todayLabel: label,
    );
  }

  static String? todayHoursLabel(
    Map<String, dynamic>? workingHours, {
    DateTime? now,
  }) {
    final hours = workingHours;
    if (hours == null || hours.isEmpty) return null;

    final todayKeys = _weekdayKeys((now ?? DateTime.now()).weekday);
    for (final key in todayKeys) {
      if (!hours.containsKey(key)) continue;
      final label = _formatHoursValue(hours[key]);
      if (label != null) return label;
    }

    for (final entry in hours.entries) {
      final normalizedKey = entry.key.toString().trim().toLowerCase();
      final isToday = todayKeys.any(
        (key) => normalizedKey == key.toLowerCase() ||
            normalizedKey.contains(key.toLowerCase()),
      );
      if (!isToday) continue;

      final label = _formatHoursValue(entry.value);
      if (label != null) return label;
    }

    return null;
  }

  static bool? isOpenNowFromTodayLabel(String? label, {DateTime? now}) {
    if (label == null || label.trim().isEmpty) return null;

    final lower = label.toLowerCase();
    if (lower.contains('closed') ||
        lower.contains('休息') ||
        lower.contains('公休') ||
        lower.contains('未營業')) {
      return false;
    }
    if (lower.contains('24 hours') ||
        lower.contains('open 24') ||
        lower.contains('24小時')) {
      return true;
    }

    final matches = RegExp(r'(\d{1,2}):(\d{2})').allMatches(label).toList();
    if (matches.length < 2) return null;

    final current = now ?? DateTime.now();
    final nowMinutes = current.hour * 60 + current.minute;

    for (var index = 0; index + 1 < matches.length; index += 2) {
      final start = _minutesFromMatch(matches[index]);
      final end = _minutesFromMatch(matches[index + 1]);
      if (start == null || end == null) continue;

      var adjustedEnd = end;
      if (adjustedEnd <= start) adjustedEnd += 24 * 60;

      final candidates = [
        nowMinutes,
        nowMinutes + 24 * 60,
      ];
      if (candidates.any((value) => value >= start && value < adjustedEnd)) {
        return true;
      }
    }

    return false;
  }

  static int? _minutesFromMatch(RegExpMatch match) {
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 24 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  static List<String> _weekdayKeys(int weekday) {
    const keys = {
      1: ['Monday', 'Mon', '星期一', '週一', '周一'],
      2: ['Tuesday', 'Tue', '星期二', '週二', '周二'],
      3: ['Wednesday', 'Wed', '星期三', '週三', '周三'],
      4: ['Thursday', 'Thu', '星期四', '週四', '周四'],
      5: ['Friday', 'Fri', '星期五', '週五', '周五'],
      6: ['Saturday', 'Sat', '星期六', '週六', '周六'],
      7: ['Sunday', 'Sun', '星期日', '星期天', '週日', '周日'],
    };
    return keys[weekday] ?? const [];
  }

  static String? _formatHoursValue(dynamic value) {
    final parts = _flattenHoursValue(value);
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  static List<String> _flattenHoursValue(dynamic value) {
    if (value == null) return const [];
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? const [] : [_cleanHoursText(trimmed)];
    }
    if (value is List) {
      return value
          .expand(_flattenHoursValue)
          .where((part) => part.trim().isNotEmpty)
          .toList();
    }
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .map(_cleanHoursText)
          .where((part) => part.trim().isNotEmpty)
          .toList();
    }
    return [_cleanHoursText(value.toString())]
        .where((part) => part.trim().isNotEmpty)
        .toList();
  }

  static String _cleanHoursText(String text) {
    var cleaned = text.trim();
    cleaned = cleaned.replaceAll(RegExp(r'^\[|\]$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^\{|\}$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.trim();
  }
}
