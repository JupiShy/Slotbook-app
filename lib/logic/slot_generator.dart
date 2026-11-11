import 'package:livecoding/models/booking.dart';
import 'package:livecoding/models/specialist.dart';
import 'package:livecoding/models/time_slot.dart';

/// Pure Dart slot calculator with no Flutter dependencies.
class SlotGenerator {
  const SlotGenerator();

  List<TimeSlot> generate({
    required Specialist specialist,
    required DateTime day,
    required List<Booking> bookings,
    required DateTime now,
    bool includeBooked = false,
  }) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final hours = specialist.workingHoursFor(dayStart);
    if (hours == null || specialist.slotMinutes <= 0) return const [];

    final step = Duration(minutes: specialist.slotMinutes);
    final workEnd = dayStart.add(hours.end);

    final breakRange = specialist.breakRange;
    final breakStart =
        breakRange == null ? null : dayStart.add(breakRange.start);
    final breakEnd = breakRange == null ? null : dayStart.add(breakRange.end);

    final blockingBookings =
        bookings.where((b) => b.isBlockingAt(now)).toList();

    final slots = <TimeSlot>[];
    var cursor = dayStart.add(hours.start);
    while (!cursor.add(step).isAfter(workEnd)) {
      final slotStart = cursor;
      final slotEnd = cursor.add(step);
      cursor = slotEnd;

      if (!slotStart.isAfter(now)) continue;

      if (breakStart != null &&
          breakEnd != null &&
          _overlaps(slotStart, slotEnd, breakStart, breakEnd)) {
        continue;
      }

      final isBooked = blockingBookings.any(
        (b) => _overlaps(slotStart, slotEnd, b.start, b.end),
      );
      if (isBooked) {
        if (includeBooked) {
          slots.add(
            TimeSlot(start: slotStart, end: slotEnd, isAvailable: false),
          );
        }
        continue;
      }

      slots.add(TimeSlot(start: slotStart, end: slotEnd));
    }
    return slots;
  }

  static bool _overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) =>
      aStart.isBefore(bEnd) && aEnd.isAfter(bStart);
}
