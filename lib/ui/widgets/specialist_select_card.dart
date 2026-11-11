import 'package:flutter/material.dart';

import 'package:livecoding/models/specialist.dart';
import 'package:livecoding/ui/formatters/date_time_formatter.dart';
import 'package:livecoding/ui/theme/app_theme.dart';

class SpecialistSelectCard extends StatelessWidget {
  const SpecialistSelectCard({
    required this.specialist,
    required this.isSelected,
    required this.avatarBackground,
    required this.onTap,
    this.width = 212,
    super.key,
  });

  final Specialist specialist;
  final bool isSelected;
  final Color avatarBackground;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                _InitialsBadge(
                  initials: DateTimeFormatter.initials(specialist.name),
                  background: isSelected
                      ? AppColors.avatarMint
                      : avatarBackground,
                  showCheck: isSelected,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SpecialistLabels(specialist: specialist),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InitialsBadge extends StatelessWidget {
  const _InitialsBadge({
    required this.initials,
    required this.background,
    required this.showCheck,
  });

  final String initials;
  final Color background;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            initials,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        if (showCheck)
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 11,
                color: AppColors.surface,
              ),
            ),
          ),
      ],
    );
  }
}

class _SpecialistLabels extends StatelessWidget {
  const _SpecialistLabels({required this.specialist});

  final Specialist specialist;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          specialist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          specialist.service,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
