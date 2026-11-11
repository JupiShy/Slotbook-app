import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:livecoding/models/specialist.dart';
import 'package:livecoding/models/time_slot.dart';
import 'package:livecoding/state/booking_cubit.dart';
import 'package:livecoding/state/booking_state.dart';
import 'package:livecoding/ui/formatters/date_time_formatter.dart';
import 'package:livecoding/ui/router/app_router.dart';
import 'package:livecoding/ui/widgets/booking_app_bar.dart';
import 'package:livecoding/ui/widgets/booking_header.dart';
import 'package:livecoding/ui/widgets/booking_sheet.dart';
import 'package:livecoding/ui/widgets/day_selector.dart';
import 'package:livecoding/ui/widgets/duration_badge.dart';
import 'package:livecoding/ui/widgets/section_header.dart';
import 'package:livecoding/ui/widgets/slots_grid.dart';
import 'package:livecoding/ui/widgets/specialist_carousel.dart';
import 'package:livecoding/ui/widgets/state_views.dart';

class SlotsScreen extends StatelessWidget {
  const SlotsScreen({super.key});

  void _leaveScreen(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _onSlotTap(
    BuildContext context,
    Specialist specialist,
    TimeSlot slot,
    DateTime today,
  ) async {
    final booked = await BookingSheet.show(
      context: context,
      specialist: specialist,
      slot: slot,
      today: today,
    );
    if (booked == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Запис підтверджено на ${DateTimeFormatter.time(slot.start)}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BookingAppBar(
        title: 'Новий запис',
        onBack: () => _leaveScreen(context),
        onClose: () => context.go(AppRoutes.home),
      ),
      body: SafeArea(
        child: BlocBuilder<BookingCubit, BookingState>(
          builder: (context, state) => _BookingScreenBody(
            state: state,
            onRetrySpecialists: () =>
                unawaited(context.read<BookingCubit>().loadSpecialists()),
            onSelectSpecialist: (s) =>
                unawaited(context.read<BookingCubit>().selectSpecialist(s)),
            onSelectDay: (d) =>
                unawaited(context.read<BookingCubit>().selectDay(d)),
            onRetrySlots: () =>
                unawaited(context.read<BookingCubit>().loadSlots()),
            onSlotTap: (specialist, slot) => _onSlotTap(
              context,
              specialist,
              slot,
              state.availableDays.first,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingScreenBody extends StatelessWidget {
  const _BookingScreenBody({
    required this.state,
    required this.onRetrySpecialists,
    required this.onSelectSpecialist,
    required this.onSelectDay,
    required this.onRetrySlots,
    required this.onSlotTap,
  });

  final BookingState state;
  final VoidCallback onRetrySpecialists;
  final ValueChanged<Specialist> onSelectSpecialist;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onRetrySlots;
  final void Function(Specialist specialist, TimeSlot slot) onSlotTap;

  @override
  Widget build(BuildContext context) {
    return switch (state.specialistsStatus) {
      LoadStatus.initial || LoadStatus.loading =>
        const LoadingView(message: 'Завантаження розкладу...'),
      LoadStatus.error => ErrorView(
          message: state.specialistsError ?? 'Помилка завантаження',
          onRetry: onRetrySpecialists,
        ),
      LoadStatus.loaded when state.selectedSpecialist == null =>
        const EmptyStateView(
          icon: Icons.person_search_outlined,
          title: 'Немає доступних фахівців',
        ),
      LoadStatus.loaded => _BookingContent(
          state: state,
          specialist: state.selectedSpecialist!,
          onSelectSpecialist: onSelectSpecialist,
          onSelectDay: onSelectDay,
          onRetrySlots: onRetrySlots,
          onSlotTap: (slot) => onSlotTap(state.selectedSpecialist!, slot),
        ),
    };
  }
}

class _BookingContent extends StatelessWidget {
  const _BookingContent({
    required this.state,
    required this.specialist,
    required this.onSelectSpecialist,
    required this.onSelectDay,
    required this.onRetrySlots,
    required this.onSlotTap,
  });

  final BookingState state;
  final Specialist specialist;
  final ValueChanged<Specialist> onSelectSpecialist;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onRetrySlots;
  final ValueChanged<TimeSlot> onSlotTap;

  String _slotsSubtitle() {
    if (state.slotsStatus == LoadStatus.loading) return 'Оновлення...';
    if (state.isDayOff) return 'Вихідний день';
    final count = state.availableSlotsCount;
    return '$count ${_pluralSlots(count)}';
  }

  static String _pluralSlots(int count) {
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'вільних слотів';
    return switch (count % 10) {
      1 => 'вільний слот',
      2 || 3 || 4 => 'вільні слоти',
      _ => 'вільних слотів',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const BookingHeader(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(),
        ),
        const SizedBox(height: 18),
        SpecialistCarousel(
          specialists: state.specialists,
          selectedSpecialist: specialist,
          onSelect: onSelectSpecialist,
        ),
        const SizedBox(height: 22),
        DaySelector(
          days: state.availableDays,
          selectedDay: state.selectedDay,
          onSelect: onSelectDay,
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(),
        ),
        const SizedBox(height: 18),
        SectionHeader(
          title: 'Доступний час',
          subtitle: _slotsSubtitle(),
          trailing: DurationBadge(minutes: specialist.slotMinutes),
        ),
        _SlotsStatusSection(
          state: state,
          onRetry: onRetrySlots,
          onSlotTap: onSlotTap,
        ),
      ],
    );
  }
}

class _SlotsStatusSection extends StatelessWidget {
  const _SlotsStatusSection({
    required this.state,
    required this.onRetry,
    required this.onSlotTap,
  });

  final BookingState state;
  final VoidCallback onRetry;
  final ValueChanged<TimeSlot> onSlotTap;

  @override
  Widget build(BuildContext context) {
    return switch (state.slotsStatus) {
      LoadStatus.initial || LoadStatus.loading => const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: LoadingView(),
        ),
      LoadStatus.error => ErrorView(
          message: state.slotsError ?? 'Не вдалося завантажити слоти',
          onRetry: onRetry,
        ),
      LoadStatus.loaded when state.isDayOff => const EmptyStateView(
          icon: Icons.event_busy_outlined,
          title: 'Вихідний день',
          subtitle: 'Оберіть інший день для запису',
        ),
      LoadStatus.loaded when state.slots.isEmpty => const EmptyStateView(
          icon: Icons.schedule_outlined,
          title: 'Немає вільних слотів',
          subtitle: 'Увесь час на цей день уже зайнятий',
        ),
      LoadStatus.loaded => SlotsGrid(
          slots: state.slots,
          onSlotTap: onSlotTap,
          shrinkWrap: true,
        ),
    };
  }
}
