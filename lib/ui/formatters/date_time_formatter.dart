abstract final class DateTimeFormatter {
  static const _weekdays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'НД'];
  static const _monthsShort = [
    'січ',
    'лют',
    'бер',
    'кві',
    'тра',
    'чер',
    'лип',
    'сер',
    'вер',
    'жов',
    'лис',
    'гру',
  ];
  static const _monthsGenitive = [
    'січня',
    'лютого',
    'березня',
    'квітня',
    'травня',
    'червня',
    'липня',
    'серпня',
    'вересня',
    'жовтня',
    'листопада',
    'грудня',
  ];

  static String time(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String weekdayShort(DateTime value) => _weekdays[value.weekday - 1];

  static String monthYear(DateTime value) =>
      '${_monthsGenitive[value.month - 1]} ${value.year}';

  static String dayMonth(DateTime value) =>
      '${value.day} ${_monthsShort[value.month - 1]}';

  static String fullDayLabel(DateTime value, {required DateTime today}) {
    final normalized = DateTime(value.year, value.month, value.day);
    if (normalized == today) return 'Сьогодні, ${dayMonth(value)}';
    if (normalized == today.add(const Duration(days: 1))) {
      return 'Завтра, ${dayMonth(value)}';
    }
    return '${weekdayShort(value)}, ${dayMonth(value)}';
  }

  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final word = parts.first;
      return word.length >= 2
          ? word.substring(0, 2).toUpperCase()
          : word.toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
