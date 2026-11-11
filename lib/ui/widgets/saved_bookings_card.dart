import 'package:flutter/material.dart';

import 'package:livecoding/models/booking.dart';
import 'package:livecoding/models/specialist.dart';
import 'package:livecoding/ui/formatters/date_time_formatter.dart';
import 'package:livecoding/ui/theme/app_theme.dart';

class SavedBookingsCard extends StatelessWidget {
  const SavedBookingsCard({
    required this.bookings,
    required this.specialists,
    super.key,
  });

  final List<Booking> bookings;
  final List<Specialist> specialists;

  String _specialistName(String specialistId) {
    for (final s in specialists) {
      if (s.id == specialistId) return s.name;
    }
    return 'Фахівець';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < bookings.length; i++) ...[
              _SavedBookingRow(
                booking: bookings[i],
                specialistName: _specialistName(bookings[i].specialistId),
              ),
              if (i < bookings.length - 1) const Divider(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _SavedBookingRow extends StatelessWidget {
  const _SavedBookingRow({
    required this.booking,
    required this.specialistName,
  });

  final Booking booking;
  final String specialistName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final date = DateTimeFormatter.dayMonth(booking.start);
    final time =
        '${DateTimeFormatter.time(booking.start)} – '
        '${DateTimeFormatter.time(booking.end)}';
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.clientName ?? '',
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$specialistName · $date, $time',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
