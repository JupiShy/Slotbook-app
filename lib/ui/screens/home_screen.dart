import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:livecoding/models/specialist.dart';
import 'package:livecoding/state/booking_cubit.dart';
import 'package:livecoding/state/booking_state.dart';
import 'package:livecoding/ui/router/app_router.dart';
import 'package:livecoding/ui/theme/app_theme.dart';
import 'package:livecoding/ui/widgets/home_hero_card.dart';
import 'package:livecoding/ui/widgets/salon_info_card.dart';
import 'package:livecoding/ui/widgets/saved_bookings_card.dart';
import 'package:livecoding/ui/widgets/section_header.dart';
import 'package:livecoding/ui/widgets/specialist_select_card.dart';
import 'package:livecoding/ui/widgets/state_views.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _goToBooking(BuildContext context, [Specialist? specialist]) {
    if (specialist != null) {
      unawaited(context.read<BookingCubit>().selectSpecialist(specialist));
    }
    context.go(AppRoutes.booking);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'SlotBook',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<BookingCubit, BookingState>(
          builder: (context, state) => _HomeBody(
            state: state,
            onBookTap: () => _goToBooking(context),
            onSpecialistTap: (s) => _goToBooking(context, s),
            onRetry: () =>
                unawaited(context.read<BookingCubit>().loadSpecialists()),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.state,
    required this.onBookTap,
    required this.onSpecialistTap,
    required this.onRetry,
  });

  final BookingState state;
  final VoidCallback onBookTap;
  final ValueChanged<Specialist> onSpecialistTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        HomeHeroCard(onBookTap: onBookTap),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Фахівці салону',
          padding: EdgeInsets.zero,
          trailing: TextButton(
            onPressed: onBookTap,
            child: const Text('Усі слоти'),
          ),
        ),
        const SizedBox(height: 8),
        _HomeSpecialistsSection(
          state: state,
          onSelect: onSpecialistTap,
          onRetry: onRetry,
        ),
        if (state.clientBookings.isNotEmpty) ...[
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Мої записи',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          SavedBookingsCard(
            bookings: state.clientBookings,
            specialists: state.specialists,
          ),
        ],
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'Про салон',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        SalonInfoCard(lastBookingLabel: state.lastConfirmedMessage),
      ],
    );
  }
}

class _HomeSpecialistsSection extends StatelessWidget {
  const _HomeSpecialistsSection({
    required this.state,
    required this.onSelect,
    required this.onRetry,
  });

  final BookingState state;
  final ValueChanged<Specialist> onSelect;
  final VoidCallback onRetry;

  static const List<Color> _palette = [
    AppColors.avatarPeach,
    AppColors.avatarMint,
    AppColors.avatarLavender,
  ];

  @override
  Widget build(BuildContext context) {
    return switch (state.specialistsStatus) {
      LoadStatus.initial || LoadStatus.loading => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: LoadingView(),
        ),
      LoadStatus.error => ErrorView(
          message: state.specialistsError ?? 'Помилка завантаження',
          onRetry: onRetry,
        ),
      LoadStatus.loaded when state.specialists.isEmpty =>
        const EmptyStateView(
          icon: Icons.person_off_outlined,
          title: 'Фахівців поки немає',
        ),
      LoadStatus.loaded => Column(
          children: [
            for (var i = 0; i < state.specialists.length; i++) ...[
              SpecialistSelectCard(
                specialist: state.specialists[i],
                width: double.infinity,
                isSelected:
                    state.specialists[i].id == state.selectedSpecialist?.id,
                avatarBackground: _palette[i % _palette.length],
                onTap: () => onSelect(state.specialists[i]),
              ),
              if (i < state.specialists.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
    };
  }
}
