import 'package:livecoding/models/booking.dart';
import 'package:livecoding/models/specialist.dart';
import 'package:livecoding/models/time_range.dart';

abstract final class SlotBookMapper {
  static const Map<String, int> _weekdayKeys = {
    'mon': DateTime.monday,
    'tue': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'thu': DateTime.thursday,
    'fri': DateTime.friday,
    'sat': DateTime.saturday,
    'sun': DateTime.sunday,
  };

  static Specialist specialistFromMap(Map<String, dynamic> map) {
    final id = _requireString(map['id'], 'specialist.id');
    final name = _requireString(map['name'], 'specialist.name');
    final service = _requireString(map['service'], 'specialist.service');
    final rawHours = map['workingHours'];
    if (rawHours is! Map<String, dynamic>) {
      throw const FormatException('Invalid workingHours');
    }

    final workingHours = <int, TimeRange?>{};
    for (final entry in _weekdayKeys.entries) {
      final rawDay = rawHours[entry.key];
      if (rawDay == null) {
        workingHours[entry.value] = null;
      } else if (rawDay is List<dynamic> && rawDay.length >= 2) {
        workingHours[entry.value] = _parseTimeRange(
          _requireString(rawDay[0], '${entry.key}[0]'),
          _requireString(rawDay[1], '${entry.key}[1]'),
        );
      } else {
        throw FormatException('Invalid workingHours entry for ${entry.key}');
      }
    }

    final rawBreak = map['break'];
    TimeRange? breakRange;
    if (rawBreak != null) {
      if (rawBreak is! Map<String, dynamic>) {
        throw const FormatException('Invalid break format');
      }
      breakRange = _parseTimeRange(
        _requireString(rawBreak['start'], 'break.start'),
        _requireString(rawBreak['end'], 'break.end'),
      );
    }

    return Specialist(
      id: id,
      name: name,
      service: service,
      slotMinutes: _parseSlotMinutes(map['slotMinutes']),
      workingHours: workingHours,
      breakRange: breakRange,
    );
  }

  static Booking bookingFromMap(Map<String, dynamic> map) {
    final rawClientName = map['clientName'];
    final rawExpiresAt = map['expiresAt'];
    return Booking(
      id: _requireString(map['id'], 'booking.id'),
      specialistId: _requireString(
        map['specialistId'],
        'booking.specialistId',
      ),
      start: DateTime.parse(
        _requireString(map['start'], 'booking.start'),
      ).toLocal(),
      end: DateTime.parse(
        _requireString(map['end'], 'booking.end'),
      ).toLocal(),
      status: _parseStatus(map['status']),
      clientName: rawClientName is String ? rawClientName : null,
      expiresAt: rawExpiresAt is String
          ? DateTime.parse(rawExpiresAt).toLocal()
          : null,
    );
  }

  static BookingStatus _parseStatus(Object? raw) {
    return switch (raw) {
      'active' => BookingStatus.active,
      'pending' => BookingStatus.pending,
      _ => BookingStatus.cancelled,
    };
  }

  static String _requireString(Object? value, String field) {
    if (value is String) return value;
    throw FormatException('Expected string for $field');
  }

  static List<Booking> normalizeBookings(List<Map<String, dynamic>> rawList) {
    final uniqueById = <String, Booking>{};
    for (final item in rawList) {
      final booking = bookingFromMap(item);
      uniqueById[booking.id] = booking;
    }
    final result = uniqueById.values.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  static int _parseSlotMinutes(Object? raw) {
    if (raw is int) return raw;
    return int.parse('$raw');
  }

  static TimeRange _parseTimeRange(String startText, String endText) {
    final start = _parseTimeOfDay(startText);
    var end = _parseTimeOfDay(endText);
    if (end <= start) {
      end += const Duration(days: 1);
    }
    return TimeRange(start: start, end: end);
  }

  static Duration _parseTimeOfDay(String hhMm) {
    final parts = hhMm.split(':');
    if (parts.length != 2) {
      throw FormatException('Invalid time format: $hhMm');
    }
    return Duration(
      hours: int.parse(parts[0]),
      minutes: int.parse(parts[1]),
    );
  }
}
