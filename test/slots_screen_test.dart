import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:livecoding/data/slotbook_exception.dart';
import 'package:livecoding/data/slotbook_repository.dart';
import 'package:livecoding/models/booking.dart';
import 'package:livecoding/models/specialist.dart';
import 'package:livecoding/models/time_range.dart';
import 'package:livecoding/state/booking_cubit.dart';
import 'package:livecoding/ui/router/app_router.dart';
import 'package:livecoding/ui/screens/slots_screen.dart';
import 'package:livecoding/ui/theme/app_theme.dart';

class _FakeSlotBookRepository implements SlotBookRepository {
  _FakeSlotBookRepository({
    this.failFirstBookingsFetch = false,
  });

  bool failFirstBookingsFetch;
  final List<Booking> _bookings = [
    Booking(
      id: 'b_booked',
      specialistId: 's1',
      start: DateTime(2026, 11, 16, 10),
      end: DateTime(2026, 11, 16, 10, 30),
      status: BookingStatus.active,
    ),
  ];

  static const _workDay = TimeRange(
    start: Duration(hours: 9),
    end: Duration(hours: 12),
  );

  final List<Specialist> _specialists = [
    const Specialist(
      id: 's1',
      name: 'Олена',
      service: 'Стрижка',
      slotMinutes: 30,
      workingHours: {
        DateTime.monday: _workDay,
        DateTime.tuesday: _workDay,
        DateTime.wednesday: _workDay,
        DateTime.thursday: _workDay,
        DateTime.friday: _workDay,
        DateTime.saturday: null,
        DateTime.sunday: null,
      },
      breakRange: TimeRange(
        start: Duration(hours: 11),
        end: Duration(hours: 11, minutes: 30),
      ),
    ),
  ];

  @override
  Future<List<Specialist>> getSpecialists() async => _specialists;

  @override
  Future<List<Booking>> getBookings(String specialistId, DateTime day) async {
    if (failFirstBookingsFetch) {
      failFirstBookingsFetch = false;
      throw const ServiceUnavailableException();
    }
    return _bookings.where((b) => b.specialistId == specialistId).toList();
  }

  @override
  Future<Booking> holdSlot({
    required String specialistId,
    required DateTime start,
  }) async {
    final hold = Booking(
      id: 'hold_1',
      specialistId: specialistId,
      start: start,
      end: start.add(const Duration(minutes: 30)),
      status: BookingStatus.pending,
      expiresAt: start.add(const Duration(minutes: 2)),
    );
    _bookings.add(hold);
    return hold;
  }

  @override
  Future<void> releaseHold(String holdId) async {
    _bookings.removeWhere((b) => b.id == holdId && b.isPending);
  }

  @override
  Future<Booking> createBooking({
    required String specialistId,
    required DateTime start,
    required String clientName,
    String? holdId,
  }) async {
    if (holdId != null) {
      _bookings.removeWhere((b) => b.id == holdId);
    }
    final booking = Booking(
      id: 'b_new',
      specialistId: specialistId,
      start: start,
      end: start.add(const Duration(minutes: 30)),
      status: BookingStatus.active,
      clientName: clientName,
    );
    _bookings.add(booking);
    return booking;
  }

  @override
  Future<List<Booking>> getSavedBookings() async =>
      List.unmodifiable(_bookings);
}

Widget _buildTestApp(BookingCubit cubit) {
  final router = GoRouter(
    initialLocation: AppRoutes.booking,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: AppRoutes.booking,
        builder: (_, _) => const SlotsScreen(),
      ),
    ],
  );
  return BlocProvider<BookingCubit>.value(
    value: cubit,
    child: MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets(
    'SlotsScreen handles retry, day-off state, and booking a free slot',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Monday 2026-11-16 at 08:00
      final fixedNow = DateTime(2026, 11, 16, 8);
      final fakeRepo = _FakeSlotBookRepository(failFirstBookingsFetch: true);
      final cubit = BookingCubit(
        repository: fakeRepo,
        clock: () => fixedNow,
      );
      unawaited(cubit.loadSpecialists());

      await tester.pumpWidget(_buildTestApp(cubit));
      await tester.pumpAndSettle();

      // 1st bookings load failed with 503 -> ErrorView with retry button
      expect(
        find.text('Сервіс тимчасово недоступний. Спробуйте ще раз.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Спробувати знову'));
      await tester.pumpAndSettle();

      // Slots: 09:00, 09:30, 10:00 (booked), 10:30, 11:30 (11:00 is break)
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('10:30'), findsOneWidget);
      expect(find.text('11:00'), findsNothing);
      expect(find.text('11:30'), findsOneWidget);

      // Select Saturday (21) -> day off
      await tester.tap(find.text('21'));
      await tester.pumpAndSettle();
      expect(find.text('Вихідний день'), findsNWidgets(2));

      // Switch back to Monday (16) and book 09:30
      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('09:30'));
      await tester.pumpAndSettle();

      expect(find.text('Підтвердження запису'), findsOneWidget);

      // Invalid digits trigger validation error
      await tester.enterText(find.byType(TextField), 'Анна123');
      await tester.tap(find.text('Записатися'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Імʼя може містити лише літери, пробіли, дефіс або апостроф.',
        ),
        findsOneWidget,
      );

      // Valid client name submits booking and shows confirmation SnackBar
      await tester.enterText(find.byType(TextField), 'Анна');
      await tester.tap(find.text('Записатися'));
      await tester.pumpAndSettle();

      expect(find.text('Запис підтверджено на 09:30'), findsOneWidget);
      final saved = await fakeRepo.getSavedBookings();
      expect(
        saved.any((b) => b.clientName == 'Анна' && b.isActive),
        isTrue,
      );

      await cubit.close();
    },
  );
}
