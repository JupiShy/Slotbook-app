import 'package:flutter/material.dart';

import 'package:livecoding/ui/theme/app_theme.dart';

class SalonInfoCard extends StatelessWidget {
  const SalonInfoCard({
    this.lastBookingLabel,
    super.key,
  });

  final String? lastBookingLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (lastBookingLabel != null) ...[
              _InfoRow(
                icon: Icons.check_circle_outline_rounded,
                title: 'Останній запис',
                subtitle: lastBookingLabel!,
                iconColor: AppColors.primary,
              ),
              const Divider(height: 24),
            ],
            const _InfoRow(
              icon: Icons.location_on_outlined,
              title: 'Адреса салону',
              subtitle: 'вул. Велика Васильківська, 72',
            ),
            const Divider(height: 24),
            const _InfoRow(
              icon: Icons.schedule_rounded,
              title: 'Графік роботи',
              subtitle: 'Пн–Сб · 09:00 – 20:00',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = AppColors.textSecondary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
