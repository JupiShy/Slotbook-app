import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:livecoding/api/slotbook_api.dart';
import 'package:livecoding/data/slotbook_repository.dart';
import 'package:livecoding/main.dart';
import 'package:livecoding/state/booking_cubit.dart';

void main() {
  testWidgets('SlotBookApp renders home, booking, and settings tabs', (
    tester,
  ) async {
    final cubit = BookingCubit(
      repository: ApiSlotBookRepository(
        SlotBookApi(latency: Duration.zero),
      ),
    );
    unawaited(cubit.loadSpecialists());

    await tester.pumpWidget(SlotBookApp(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.text('SlotBook'), findsOneWidget);
    expect(find.text('Олена'), findsOneWidget);

    await tester.tap(find.text('Запис'));
    await tester.pumpAndSettle();

    expect(find.text('Новий запис'), findsOneWidget);
    expect(find.text('Оберіть зручний\nчас для візиту'), findsOneWidget);

    await tester.tap(find.text('Налаштування'));
    await tester.pumpAndSettle();

    expect(find.text('Нагадування про візит'), findsOneWidget);
    expect(find.text('Читання памʼяті (Debug)'), findsOneWidget);

    await tester.tap(find.text('Читання памʼяті (Debug)'));
    await tester.pumpAndSettle();

    expect(find.text('Памʼять застосунку'), findsOneWidget);
    expect(find.text('Записів у БД'), findsOneWidget);

    await cubit.close();
  });
}
