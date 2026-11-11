import 'package:flutter/material.dart';

import 'package:livecoding/ui/theme/app_theme.dart';

class DurationBadge extends StatelessWidget {
  const DurationBadge({
    required this.minutes,
    super.key,
  });

  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            '$minutes хв',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
