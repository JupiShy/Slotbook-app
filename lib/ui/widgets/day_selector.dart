import 'package:flutter/material.dart';

import 'package:livecoding/ui/formatters/date_time_formatter.dart';
import 'package:livecoding/ui/theme/app_theme.dart';
import 'package:livecoding/ui/widgets/section_header.dart';

class DaySelector extends StatelessWidget {
  const DaySelector({
    required this.days,
    required this.selectedDay,
    required this.onSelect,
    super.key,
  });

  final List<DateTime> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Дата',
          trailing: Text(
            DateTimeFormatter.monthYear(selectedDay),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: _DayChip(
                    day: days[i],
                    isSelected: _isSameDate(days[i], selectedDay),
                    isToday: i == 0,
                    onTap: () => onSelect(days[i]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shadow = isSelected
        ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: shadow,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: _DayChipContent(
              day: day,
              isToday: isToday,
              isSelected: isSelected,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayChipContent extends StatelessWidget {
  const _DayChipContent({
    required this.day,
    required this.isToday,
    required this.isSelected,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final topColor = isSelected
        ? AppColors.surface.withValues(alpha: 0.85)
        : AppColors.textSecondary;
    final dayColor = isSelected ? AppColors.surface : AppColors.textPrimary;
    final label = isToday ? 'СЬОГОДНІ' : DateTimeFormatter.weekdayShort(day);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.2,
                  color: topColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${day.day}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: dayColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
