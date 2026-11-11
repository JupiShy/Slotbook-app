import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:livecoding/models/booking.dart';
import 'package:livecoding/models/specialist.dart';
import 'package:livecoding/models/time_slot.dart';
import 'package:livecoding/services/error_logger_service.dart';
import 'package:livecoding/state/booking_cubit.dart';
import 'package:livecoding/state/booking_state.dart';
import 'package:livecoding/ui/formatters/date_time_formatter.dart';
import 'package:livecoding/ui/theme/app_theme.dart';

class MemoryDebugSheet extends StatelessWidget {
  const MemoryDebugSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<BookingCubit>();
    unawaited(cubit.refreshSavedBookings());
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (_) => BlocProvider<BookingCubit>.value(
        value: cubit,
        child: const MemoryDebugSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BookingCubit>();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) => SafeArea(
        top: false,
        child: BlocBuilder<BookingCubit, BookingState>(
          builder: (context, state) => _MemoryDebugBody(
            state: state,
            errors: cubit.loggedErrors,
            customKeys: cubit.crashCustomKeys,
            userId: cubit.crashUserId,
            scrollController: scrollController,
            onRefresh: () => unawaited(cubit.refreshSavedBookings()),
          ),
        ),
      ),
    );
  }
}

class _MemoryDebugBody extends StatelessWidget {
  const _MemoryDebugBody({
    required this.state,
    required this.errors,
    required this.customKeys,
    required this.userId,
    required this.scrollController,
    required this.onRefresh,
  });

  final BookingState state;
  final List<ErrorLogEntry> errors;
  final Map<String, Object> customKeys;
  final String? userId;
  final ScrollController scrollController;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DebugHeader(onRefresh: onRefresh),
        const Divider(),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              _DebugSummaryRow(state: state, errorCount: errors.length),
              const SizedBox(height: 18),
              _DebugSlotsSection(state: state),
              const SizedBox(height: 18),
              _DebugClientsSection(
                bookings: state.savedBookings,
                specialists: state.specialists,
              ),
              if (customKeys.isNotEmpty || userId != null) ...[
                const SizedBox(height: 18),
                _DebugCrashlyticsSection(
                  userId: userId,
                  customKeys: customKeys,
                ),
              ],
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 18),
                _DebugErrorsSection(errors: errors),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DebugHeader extends StatelessWidget {
  const _DebugHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Памʼять застосунку',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          IconButton(
            tooltip: 'Оновити',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Закрити',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _DebugSummaryRow extends StatelessWidget {
  const _DebugSummaryRow({
    required this.state,
    required this.errorCount,
  });

  final BookingState state;
  final int errorCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Записів у БД',
            value: '${state.savedBookings.length}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'Слотів',
            value: '${state.availableSlotsCount}/${state.slots.length}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'Помилок',
            value: '$errorCount',
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugSlotsSection extends StatelessWidget {
  const _DebugSlotsSection({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final specialistName = state.selectedSpecialist?.name ?? 'не обрано';
    final dayLabel = DateTimeFormatter.dayMonth(state.selectedDay);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Слоти в памʼяті ($specialistName · $dayLabel)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (state.activeHold != null) ...[
              const SizedBox(height: 6),
              Text(
                'Активний hold: ${state.activeHold!.id}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ],
            const SizedBox(height: 10),
            if (state.slots.isEmpty)
              Text(
                state.isDayOff ? 'Вихідний день' : 'Слоти не завантажені',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in state.slots) _SlotMemoryChip(slot: slot),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SlotMemoryChip extends StatelessWidget {
  const _SlotMemoryChip({required this.slot});

  final TimeSlot slot;

  @override
  Widget build(BuildContext context) {
    final time =
        '${DateTimeFormatter.time(slot.start)}-'
        '${DateTimeFormatter.time(slot.end)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: slot.isAvailable
            ? AppColors.primarySoft
            : AppColors.disabledSlot,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$time · ${slot.isAvailable ? 'вільний' : 'зайнятий'}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: slot.isAvailable
                  ? AppColors.primary
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _DebugClientsSection extends StatelessWidget {
  const _DebugClientsSection({
    required this.bookings,
    required this.specialists,
  });

  final List<Booking> bookings;
  final List<Specialist> specialists;

  String _specialistName(String id) {
    for (final s in specialists) {
      if (s.id == id) return s.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Клієнти та записи в БД (${bookings.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            if (bookings.isEmpty)
              Text(
                'Локальна БД порожня',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              )
            else
              for (var i = 0; i < bookings.length; i++) ...[
                _BookingMemoryRow(
                  booking: bookings[i],
                  specialistName: _specialistName(bookings[i].specialistId),
                ),
                if (i < bookings.length - 1) const Divider(height: 16),
              ],
          ],
        ),
      ),
    );
  }
}

class _BookingMemoryRow extends StatelessWidget {
  const _BookingMemoryRow({
    required this.booking,
    required this.specialistName,
  });

  final Booking booking;
  final String specialistName;

  @override
  Widget build(BuildContext context) {
    final client = booking.clientName?.isNotEmpty == true
        ? booking.clientName!
        : 'Без імені (seed)';
    final date = DateTimeFormatter.dayMonth(booking.start);
    final time =
        '${DateTimeFormatter.time(booking.start)}–'
        '${DateTimeFormatter.time(booking.end)}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '$specialistName · $date, $time · id:${booking.id}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusPill(status: booking.status),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      BookingStatus.active => (AppColors.primarySoft, AppColors.primary),
      BookingStatus.pending => (
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
        ),
      BookingStatus.cancelled => (
          AppColors.disabledSlot,
          AppColors.textSecondary,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _DebugErrorsSection extends StatelessWidget {
  const _DebugErrorsSection({required this.errors});

  final List<ErrorLogEntry> errors;

  @override
  Widget build(BuildContext context) {
    final latest = errors.reversed.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Останні помилки (${errors.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            for (final entry in latest) ...[
              Text(
                '${DateTimeFormatter.time(entry.timestamp)} · '
                '${entry.reason ?? entry.error}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _DebugCrashlyticsSection extends StatelessWidget {
  const _DebugCrashlyticsSection({
    required this.userId,
    required this.customKeys,
  });

  final String? userId;
  final Map<String, Object> customKeys;

  @override
  Widget build(BuildContext context) {
    final entries = customKeys.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Crashlytics ключі (${entries.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (userId != null) ...[
              const SizedBox(height: 6),
              Text(
                'userId: $userId',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: 8),
            for (final entry in entries) ...[
              Text(
                '${entry.key}: ${entry.value}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 3),
            ],
          ],
        ),
      ),
    );
  }
}
