import 'package:flutter/material.dart';

import 'package:livecoding/models/time_slot.dart';
import 'package:livecoding/ui/formatters/date_time_formatter.dart';
import 'package:livecoding/ui/theme/app_theme.dart';

class SlotChip extends StatelessWidget {
  const SlotChip({
    required this.slot,
    required this.onTap,
    super.key,
  });

  final TimeSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = slot.isAvailable;
    final background =
        enabled ? AppColors.surface : AppColors.disabledSlot;
    final textColor = enabled ? AppColors.textPrimary : AppColors.textMuted;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: enabled ? Border.all(color: AppColors.border) : null,
          ),
          child: Text(
            DateTimeFormatter.time(slot.start),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                  decoration: enabled ? null : TextDecoration.lineThrough,
                  decorationColor: AppColors.textMuted,
                ),
          ),
        ),
      ),
    );
  }
}
