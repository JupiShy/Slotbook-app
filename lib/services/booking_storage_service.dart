import 'package:livecoding/models/booking.dart';

abstract interface class BookingStorageService {
  Future<void> saveBooking(Booking booking);

  Future<void> saveAll(List<Booking> bookings);

  Future<void> deleteById(String id);

  Future<List<Booking>> getAllBookings();

  Future<List<Booking>> getBookingsFor(String specialistId, DateTime day);

  Future<Booking?> findById(String id);

  Future<void> clear();
}

/// In-memory local database for bookings, suitable for tests and app runtime.
class InMemoryBookingStorageService implements BookingStorageService {
  final Map<String, Booking> _records = {};

  @override
  Future<void> saveBooking(Booking booking) async {
    final existing = _records[booking.id];
    _records[booking.id] = booking.clientName == null && existing != null
        ? booking.copyWith(clientName: existing.clientName)
        : booking;
  }

  @override
  Future<void> saveAll(List<Booking> bookings) async {
    for (final booking in bookings) {
      await saveBooking(booking);
    }
  }

  @override
  Future<void> deleteById(String id) async {
    _records.remove(id);
  }

  @override
  Future<List<Booking>> getAllBookings() async {
    final list = _records.values.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return List.unmodifiable(list);
  }

  @override
  Future<List<Booking>> getBookingsFor(
    String specialistId,
    DateTime day,
  ) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final filtered = _records.values
        .where((b) => b.specialistId == specialistId)
        .where((b) => b.start.isBefore(dayEnd) && b.end.isAfter(dayStart))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return List.unmodifiable(filtered);
  }

  @override
  Future<Booking?> findById(String id) async => _records[id];

  @override
  Future<void> clear() async => _records.clear();
}
