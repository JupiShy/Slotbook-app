import 'package:flutter/material.dart';

import 'package:livecoding/ui/theme/app_theme.dart';

class BookingHeader extends StatelessWidget {
  const BookingHeader({
    this.salonName = 'SlotBook · Салон',
    this.headline = 'Оберіть зручний\nчас для візиту',
    this.address = 'вул. Велика Васильківська, 72',
    super.key,
  });

  final String salonName;
  final String headline;
  final String address;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            salonName,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            headline,
            style: textTheme.headlineMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.15,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          _LocationRow(address: address),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          address,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
        ),
      ],
    );
  }
}
