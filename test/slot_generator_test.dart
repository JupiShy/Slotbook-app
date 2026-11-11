import 'package:flutter_test/flutter_test.dart';

import 'package:livecoding/logic/slot_generator.dart';
import 'package:livecoding/models/booking.dart';
import 'package:livecoding/models/specialist.dart';
import 'package:livecoding/models/time_range.dart';

void main() {
  const generator = SlotGenerator();

  Specialist makeSpecialist({
    int slotMinutes = 30,
    Map<int, TimeRange?>? workingHours,
    TimeRange? breakRange,
  }) {
    const defaultRange = TimeRange(
      start: Duration(hours: 9),
      end: Duration(hours: 18),
    );
    return Specialist(
      id: 's1',
      name: 'Олена',
      service: 'Стрижка',
      slotMinutes: slotMinutes,
      workingHours: workingHours ??
          {
            DateTime.monday: defaultRange,
            DateTime.tuesday: defaultRange,
            DateTime.wednesday: defaultRange,
            DateTime.thursday: defaultRange,
            DateTime.friday: defaultRange,
            DateTime.saturday: defaultRange,
            DateTime.sunday: null,
          },
      breakRange: breakRange,
    );
  }

  group('SlotGenerator', () {
    test('1. returns empty list on day off even if bookings exist', () {
      // 2026-11-15 is a Sunday
      final sunday = DateTime(2026, 11, 15);
      final specialist = makeSpecialist();
      final bookings = [
        Booking(
          id: 'b1',
          specialistId: 's1',
          start: DateTime(2026, 11, 15, 10),
          end: DateTime(2026, 11, 15, 11),
          status: BookingStatus.active,
        ),
      ];

      final slots = generator.generate(
        specialist: specialist,
        day: sunday,
        bookings: bookings,
        now: DateTime(2026, 11, 15, 8),
      );

      expect(slots, isEmpty);
    });

    test(
      '2. excludes partial remainder slot that exceeds workingHours end',
      () {
      final monday = DateTime(2026, 11, 16);
      final specialist = makeSpecialist(
        slotMinutes: 45,
        workingHours: {
          DateTime.monday: const TimeRange(
            start: Duration(hours: 9),
            end: Duration(hours: 17, minutes: 30),
          ),
        },
      );

      final slots = generator.generate(
        specialist: specialist,
        day: monday,
        bookings: const [],
        now: DateTime(2026, 11, 16, 8),
      );

      expect(slots.first.start, DateTime(2026, 11, 16, 9));
      // 16:30 -> 17:15 fits; 17:15 -> 18:00 exceeds 17:30 and must be excluded
      expect(slots.last.start, DateTime(2026, 11, 16, 16, 30));
      expect(slots.last.end, DateTime(2026, 11, 16, 17, 15));
    });

    test(
      '3. skips slots overlapping break even when includeBooked is true',
      () {
      final monday = DateTime(2026, 11, 16);
      final specialist = makeSpecialist(
        slotMinutes: 45,
        workingHours: {
          DateTime.monday: const TimeRange(
            start: Duration(hours: 9),
            end: Duration(hours: 17, minutes: 30),
          ),
        },
        breakRange: const TimeRange(
          start: Duration(hours: 12, minutes: 30),
          end: Duration(hours: 13, minutes: 15),
        ),
      );

      final slots = generator.generate(
        specialist: specialist,
        day: monday,
        bookings: const [],
        now: DateTime(2026, 11, 16, 8),
        includeBooked: true,
      );

      final starts = slots.map((s) => s.start).toList();
      expect(starts, isNot(contains(DateTime(2026, 11, 16, 12))));
      expect(starts, isNot(contains(DateTime(2026, 11, 16, 12, 45))));
      expect(starts, contains(DateTime(2026, 11, 16, 11, 15)));
      expect(starts, contains(DateTime(2026, 11, 16, 13, 30)));
    });

    test(
      '4. blocks all slots overlapping off-grid and multi-slot bookings',
      () {
      final monday = DateTime(2026, 11, 16);
      final specialist = makeSpecialist();
      final bookings = [
        // 10:15 - 11:00 overlaps 10:00-10:30 and 10:30-11:00
        Booking(
          id: 'b1',
          specialistId: 's1',
          start: DateTime(2026, 11, 16, 10, 15),
          end: DateTime(2026, 11, 16, 11),
          status: BookingStatus.active,
        ),
        // 15:00 - 16:30 spans 3 slots
        Booking(
          id: 'b3',
          specialistId: 's1',
          start: DateTime(2026, 11, 16, 15),
          end: DateTime(2026, 11, 16, 16, 30),
          status: BookingStatus.active,
        ),
      ];

      final freeSlots = generator.generate(
        specialist: specialist,
        day: monday,
        bookings: bookings,
        now: DateTime(2026, 11, 16, 8),
      );
      final freeStarts = freeSlots.map((s) => s.start).toList();

      expect(freeStarts, contains(DateTime(2026, 11, 16, 9, 30)));
      expect(freeStarts, isNot(contains(DateTime(2026, 11, 16, 10))));
      expect(freeStarts, isNot(contains(DateTime(2026, 11, 16, 10, 30))));
      expect(freeStarts, contains(DateTime(2026, 11, 16, 11)));
      expect(freeStarts, isNot(contains(DateTime(2026, 11, 16, 15))));
      expect(freeStarts, isNot(contains(DateTime(2026, 11, 16, 15, 30))));
      expect(freeStarts, isNot(contains(DateTime(2026, 11, 16, 16))));
      expect(freeStarts, contains(DateTime(2026, 11, 16, 16, 30)));
    });

    test('5. ignores cancelled bookings and keeps slot available', () {
      final monday = DateTime(2026, 11, 16);
      final specialist = makeSpecialist();
      final bookings = [
        Booking(
          id: 'b2',
          specialistId: 's1',
          start: DateTime(2026, 11, 16, 11),
          end: DateTime(2026, 11, 16, 11, 30),
          status: BookingStatus.cancelled,
        ),
      ];

      final slots = generator.generate(
        specialist: specialist,
        day: monday,
        bookings: bookings,
        now: DateTime(2026, 11, 16, 8),
      );

      expect(
        slots.any((s) => s.start == DateTime(2026, 11, 16, 11)),
        isTrue,
      );
    });

    test('6. hides slots that have already started relative to now', () {
      final monday = DateTime(2026, 11, 16);
      final specialist = makeSpecialist();

      final slots = generator.generate(
        specialist: specialist,
        day: monday,
        bookings: const [],
        // Exact start of 11:00 slot -> 11:00 has already started, 11:30 is next
        now: DateTime(2026, 11, 16, 11),
      );

      expect(slots.first.start, DateTime(2026, 11, 16, 11, 30));
    });

    test('7. supports 18:00-00:00 shift and cross-midnight booking', () {
      final monday = DateTime(2026, 11, 16);
      final specialist = makeSpecialist(
        slotMinutes: 90,
        workingHours: {
          DateTime.monday: const TimeRange(
            start: Duration(hours: 18),
            end: Duration(hours: 24),
          ),
        },
      );
      final bookings = [
        // 23:30 today -> 00:30 tomorrow overlaps 22:30-00:00 slot
        Booking(
          id: 'b9',
          specialistId: 's4',
          start: DateTime(2026, 11, 16, 23, 30),
          end: DateTime(2026, 11, 17, 0, 30),
          status: BookingStatus.active,
        ),
      ];

      final slots = generator.generate(
        specialist: specialist,
        day: monday,
        bookings: bookings,
        now: DateTime(2026, 11, 16, 17),
      );

      final starts = slots.map((s) => s.start).toList();
      expect(starts, [
        DateTime(2026, 11, 16, 18),
        DateTime(2026, 11, 16, 19, 30),
        DateTime(2026, 11, 16, 21),
      ]);
    });

    test('8. active pending hold blocks slot while expired hold does not', () {
      final monday = DateTime(2026, 11, 16);
      final now = DateTime(2026, 11, 16, 8);
      final specialist = makeSpecialist();
      final bookings = [
        Booking(
          id: 'hold_active',
          specialistId: 's1',
          start: DateTime(2026, 11, 16, 10),
          end: DateTime(2026, 11, 16, 10, 30),
          status: BookingStatus.pending,
          expiresAt: now.add(const Duration(minutes: 2)),
        ),
        Booking(
          id: 'hold_expired',
          specialistId: 's1',
          start: DateTime(2026, 11, 16, 11),
          end: DateTime(2026, 11, 16, 11, 30),
          status: BookingStatus.pending,
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ),
      ];

      final slots = generator.generate(
        specialist: specialist,
        day: monday,
        bookings: bookings,
        now: now,
      );
      final starts = slots.map((s) => s.start).toList();

      expect(starts, isNot(contains(DateTime(2026, 11, 16, 10))));
      expect(starts, contains(DateTime(2026, 11, 16, 11)));
    });
  });
}
