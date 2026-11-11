import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:livecoding/models/specialist.dart';
import 'package:livecoding/ui/theme/app_theme.dart';
import 'package:livecoding/ui/widgets/section_header.dart';
import 'package:livecoding/ui/widgets/specialist_select_card.dart';

class SpecialistCarousel extends StatelessWidget {
  const SpecialistCarousel({
    required this.specialists,
    required this.selectedSpecialist,
    required this.onSelect,
    super.key,
  });

  final List<Specialist> specialists;
  final Specialist? selectedSpecialist;
  final ValueChanged<Specialist> onSelect;

  static const List<Color> _pastelPalette = [
    AppColors.avatarPeach,
    AppColors.avatarMint,
    AppColors.avatarLavender,
  ];

  void _openAllSpecialists(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        backgroundColor: AppColors.background,
        builder: (_) => _SpecialistsPickerSheet(
          specialists: specialists,
          selectedSpecialist: selectedSpecialist,
          onSelect: (specialist) {
            context.pop();
            onSelect(specialist);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Фахівець',
          trailing: _AllSpecialistsButton(
            onTap: () => _openAllSpecialists(context),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: specialists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final specialist = specialists[index];
              return SpecialistSelectCard(
                specialist: specialist,
                isSelected: specialist.id == selectedSpecialist?.id,
                avatarBackground:
                    _pastelPalette[index % _pastelPalette.length],
                onTap: () => onSelect(specialist),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AllSpecialistsButton extends StatelessWidget {
  const _AllSpecialistsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Усі',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialistsPickerSheet extends StatelessWidget {
  const _SpecialistsPickerSheet({
    required this.specialists,
    required this.selectedSpecialist,
    required this.onSelect,
  });

  final List<Specialist> specialists;
  final Specialist? selectedSpecialist;
  final ValueChanged<Specialist> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Усі фахівці',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < specialists.length; i++) ...[
              SpecialistSelectCard(
                specialist: specialists[i],
                width: double.infinity,
                isSelected: specialists[i].id == selectedSpecialist?.id,
                avatarBackground: SpecialistCarousel._pastelPalette[
                    i % SpecialistCarousel._pastelPalette.length],
                onTap: () => onSelect(specialists[i]),
              ),
              if (i < specialists.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
