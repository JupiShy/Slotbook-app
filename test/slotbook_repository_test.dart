import 'package:flutter_test/flutter_test.dart';

import 'package:livecoding/api/slotbook_api.dart';
import 'package:livecoding/data/slotbook_exception.dart';
import 'package:livecoding/data/slotbook_repository.dart';
import 'package:livecoding/models/booking.dart';
import 'package:livecoding/services/booking_storage_service.dart';
import 'package:livecoding/services/error_logger_service.dart';

void main() {
  group('ApiSlotBookRepository with storage & error logger', () {
    test('silently retries 503 on 4th request and logs transient error',
        () async {
      final logger = AppErrorLoggerService();
      final storage = InMemoryBookingStorageService();
      final repo = ApiSlotBookRepository(
        SlotBookApi(latency: Duration.zero),
        storage: storage,
        errorLogger: logger,
      );
      final today = DateTime.now();

      await repo.getSpecialists(); // #1
      await repo.getBookings('s1', today); // #2
      await repo.getBookings('s2', today); // #3

      // #4 throws 503 internally, silent retry #5 succeeds
      final specialists = await repo.getSpecialists();
      expect(specialists, isNotEmpty);
      expect(logger.entries, hasLength(1));
      expect(logger.entries.first.reason, contains('transient 503'));
      expect(logger.entries.first.fatal, isFalse);
    });

    test('throws ServiceUnavailableException when retries are disabled',
        () async {
      final logger = AppErrorLoggerService();
      final repo = ApiSlotBookRepository(
        SlotBookApi(latency: Duration.zero),
        errorLogger: logger,
        maxUnavailableRetries: 0,
      );
      final today = DateTime.now();

      await repo.getSpecialists(); // #1
      await repo.getBookings('s1', today); // #2
      await repo.getBookings('s2', today); // #3

      await expectLater(
        repo.getSpecialists(),
        throwsA(isA<ServiceUnavailableException>()),
      );
      expect(logger.entries, hasLength(1));
      expect(logger.entries.first.context['statusCode'], 503);
    });

    test('does not retry 422 validation errors and logs error', () async {
      final logger = AppErrorLoggerService();
      final repo = ApiSlotBookRepository(
        SlotBookApi(latency: Duration.zero),
        errorLogger: logger,
      );

      await expectLater(
        repo.createBooking(
          specialistId: 's1',
          start: DateTime.now(),
          clientName: '   ',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(logger.entries, hasLength(1));
      expect(logger.entries.first.context['statusCode'], 422);
    });

    test('persists created booking with clientName in local DB and logs 409',
        () async {
      final logger = AppErrorLoggerService();
      final storage = InMemoryBookingStorageService();
      final repo = ApiSlotBookRepository(
        SlotBookApi(latency: Duration.zero),
        storage: storage,
        errorLogger: logger,
      );
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final slotStart =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 12);

      // 1st createBooking triggers simulated 409 race condition
      await expectLater(
        repo.createBooking(
          specialistId: 's1',
          start: slotStart,
          clientName: 'Анна',
        ),
        throwsA(isA<SlotConflictException>()),
      );
      expect(logger.entries.last.context['statusCode'], 409);

      // 2nd createBooking on another slot succeeds and persists clientName
      final nextStart = slotStart.add(const Duration(minutes: 30));
      final created = await repo.createBooking(
        specialistId: 's1',
        start: nextStart,
        clientName: 'Анна',
      );

      expect(created.clientName, 'Анна');
      final saved = await repo.getSavedBookings();
      expect(saved.any((b) => b.id == created.id && b.clientName == 'Анна'),
          isTrue);
      final dayBookings = await repo.getBookings('s1', tomorrow);
      expect(
        dayBookings.any((b) => b.id == created.id && b.clientName == 'Анна'),
        isTrue,
      );
    });

    test('409 on 1st createBooking occurs even with silent retry disabled',
        () async {
      final repo = ApiSlotBookRepository(
        SlotBookApi(latency: Duration.zero),
        maxUnavailableRetries: 0,
      );
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final slotStart =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 12);

      await expectLater(
        repo.createBooking(
          specialistId: 's1',
          start: slotStart,
          clientName: 'Анна',
        ),
        throwsA(isA<SlotConflictException>()),
      );
    });

    test('holdSlot reserves slot as pending and confirms into active',
        () async {
      final storage = InMemoryBookingStorageService();
      final repo = ApiSlotBookRepository(
        SlotBookApi(latency: Duration.zero),
        storage: storage,
      );
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final firstSlot =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 12);
      final secondSlot = firstSlot.add(const Duration(minutes: 30));

      // 1st hold triggers simulated 409 race condition
      await expectLater(
        repo.holdSlot(specialistId: 's1', start: firstSlot),
        throwsA(isA<SlotConflictException>()),
      );

      // 2nd hold succeeds with status == pending
      final hold = await repo.holdSlot(specialistId: 's1', start: secondSlot);
      expect(hold.status, BookingStatus.pending);
      expect(hold.expiresAt, isNotNull);

      // Another hold on the same slot fails with 409
      await expectLater(
        repo.holdSlot(specialistId: 's1', start: secondSlot),
        throwsA(isA<SlotConflictException>()),
      );

      // Confirming with holdId replaces pending hold with active booking
      final confirmed = await repo.createBooking(
        specialistId: 's1',
        start: secondSlot,
        clientName: 'Олена',
        holdId: hold.id,
      );
      expect(confirmed.status, BookingStatus.active);
      expect(confirmed.clientName, 'Олена');
      expect(await storage.findById(hold.id), isNull);
    });

    test('releaseHold frees pending slot and expired holds are purged',
        () async {
      var now = DateTime(2026, 11, 11, 10);
      final storage = InMemoryBookingStorageService();
      final repo = ApiSlotBookRepository(
        SlotBookApi(
          latency: Duration.zero,
          clock: () => now,
        ),
        storage: storage,
      );
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final firstSlot =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 12);
      final secondSlot = firstSlot.add(const Duration(minutes: 30));

      // Consume initial simulated race
      await expectLater(
        repo.holdSlot(specialistId: 's1', start: firstSlot),
        throwsA(isA<SlotConflictException>()),
      );

      // Hold & release
      final hold = await repo.holdSlot(specialistId: 's1', start: secondSlot);
      await repo.releaseHold(hold.id);
      expect(await storage.findById(hold.id), isNull);

      // Hold again and advance clock past TTL
      final expiringHold =
          await repo.holdSlot(specialistId: 's1', start: secondSlot);
      now = now.add(const Duration(minutes: 3));

      // Expired hold should be purged, so new hold on same slot succeeds
      final freshHold =
          await repo.holdSlot(specialistId: 's1', start: secondSlot);
      expect(freshHold.id, isNot(expiringHold.id));
    });
  });
}
