import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:livecoding/api/slotbook_api.dart';
import 'package:livecoding/state/booking_cubit.dart';
import 'package:livecoding/state/booking_state.dart';
import 'package:livecoding/ui/widgets/memory_debug_sheet.dart';
import 'package:livecoding/ui/widgets/section_header.dart';
import 'package:livecoding/ui/widgets/settings_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'Налаштування',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<BookingCubit, BookingState>(
          builder: (context, state) => _SettingsBody(state: state),
        ),
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.state});

  final BookingState state;

  void _onTestCrashTap(BuildContext context, BookingCubit cubit) {
    if (!cubit.hasCrashMonitor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crashlytics доступний лише на Android / iOS'),
        ),
      );
      return;
    }
    cubit.triggerTestCrash();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BookingCubit>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const SectionHeader(
          title: 'Запис і відображення',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 10),
        SettingsCard(
          children: [
            SettingsSwitchTile(
              icon: Icons.notifications_none_rounded,
              title: 'Нагадування про візит',
              subtitle: 'Сповіщення за 1 годину до запису',
              value: state.notificationsEnabled,
              onChanged: (v) => cubit.setNotificationsEnabled(value: v),
            ),
            SettingsSwitchTile(
              icon: Icons.visibility_outlined,
              title: 'Показувати зайняті слоти',
              subtitle: 'Закреслений час у сітці запису',
              value: state.showUnavailableSlots,
              onChanged: (v) => cubit.setShowUnavailableSlots(value: v),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SectionHeader(
          title: 'Діагностика',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 10),
        SettingsCard(
          children: [
            SettingsSwitchTile(
              icon: Icons.bug_report_outlined,
              title: 'Сценарій інциденту API',
              subtitle: 'Перемикає ApiScenario.incident для тестування',
              value: state.scenario == ApiScenario.incident,
              onChanged: (v) => unawaited(
                cubit.setScenario(
                  v ? ApiScenario.incident : ApiScenario.normal,
                ),
              ),
            ),
            SettingsActionTile(
              icon: Icons.memory_rounded,
              title: 'Читання памʼяті (Debug)',
              subtitle: 'Слоти, клієнти в БД та логи помилок',
              onTap: () => unawaited(MemoryDebugSheet.show(context)),
            ),
            SettingsActionTile(
              icon: Icons.warning_amber_rounded,
              title: 'Тестовий краш (Crashlytics)',
              subtitle: 'Перевірка AppCrashMonitor.testCrash()',
              onTap: () => _onTestCrashTap(context, cubit),
            ),
            const SettingsInfoTile(
              icon: Icons.location_on_outlined,
              title: 'Філія',
              value: 'вул. В. Васильківська, 72',
            ),
            const SettingsInfoTile(
              icon: Icons.info_outline_rounded,
              title: 'Версія застосунку',
              value: '1.0.0',
            ),
          ],
        ),
      ],
    );
  }
}
