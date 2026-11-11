import 'package:flutter/material.dart';

import 'package:livecoding/ui/theme/app_theme.dart';

class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({
    required this.onBookTap,
    super.key,
  });

  final VoidCallback onBookTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroTag(),
          const SizedBox(height: 12),
          Text(
            'Швидкий запис\nбез дзвінків',
            style: textTheme.headlineSmall?.copyWith(
              color: AppColors.surface,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Оберіть майстра, день і вільний час у кілька дотиків.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.surface.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onBookTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.calendar_today_rounded, size: 16),
            label: const Text('Обрати час'),
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'SlotBook · Салон',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.surface,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
