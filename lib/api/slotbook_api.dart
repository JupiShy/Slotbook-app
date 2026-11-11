// SlotBook mock API — однаковий для всіх кандидатів. НЕ змінювати цей файл.
//
// Поклади файл у lib/api/slotbook_api.dart свого проєкту.
// Залежностей немає, тільки dart:async.


import 'dart:async';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

enum ApiScenario { normal, incident }

class SlotBookApi {
  SlotBookApi({
    this.scenario = ApiScenario.normal,
    this.latency = const Duration(milliseconds: 800),
    this.holdDuration = const Duration(minutes: 2),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now {
    _specialists = _seedSpecialists();
    _bookings = _seedBookings();
  }

  final ApiScenario scenario;
  final Duration latency;
  final Duration holdDuration;
  final DateTime Function() _now;

  late final List<Map<String, dynamic>> _specialists;
  late final List<Map<String, dynamic>> _bookings;
  int _requests = 0;
  bool _raceSimulated = false;

  Future<List<Map<String, dynamic>>> getSpecialists() async {
    await _network();
    return _specialists.map(_copy).toList();
  }

  Future<List<Map<String, dynamic>>> getBookings(
    String specialistId,
    DateTime day,
  ) async {
    await _network();
    _purgeExpiredHolds();
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _bookings
        .where((b) => b['specialistId'] == specialistId)
        .where((b) {
          final start = DateTime.parse(b['start'] as String).toLocal();
          final end = DateTime.parse(b['end'] as String).toLocal();
          return start.isBefore(dayEnd) && end.isAfter(dayStart);
        })
        .map(_copy)
        .toList();
  }

  Future<Map<String, dynamic>> holdSlot({
    required String specialistId,
    required DateTime start,
  }) async {
    await _network();
    _purgeExpiredHolds();
    final specialist = _findSpecialist(specialistId);
    final minutes = int.parse('${specialist['slotMinutes']}');
    final end = start.add(Duration(minutes: minutes));

    if (!_raceSimulated) {
      _raceSimulated = true;
      _bookings.add(_booking('race', specialistId, start, end));
      throw ApiException(409, 'Slot already taken');
    }

    if (_hasOverlap(specialistId, start, end)) {
      throw ApiException(409, 'Slot already taken');
    }

    final now = _now();
    final hold = _booking(
      'hold_${now.microsecondsSinceEpoch}',
      specialistId,
      start,
      end,
      status: 'pending',
      expiresAt: now.add(holdDuration),
    );
    _bookings.add(hold);
    return _copy(hold);
  }

  Future<void> releaseHold(String bookingId) async {
    await _network();
    _purgeExpiredHolds();
    _bookings.removeWhere(
      (b) => b['id'] == bookingId && b['status'] == 'pending',
    );
  }

  Future<Map<String, dynamic>> createBooking({
    required String specialistId,
    required DateTime start,
    required String clientName,
    String? holdId,
  }) async {
    await _network();
    _purgeExpiredHolds();
    final specialist = _findSpecialist(specialistId);
    if (clientName.trim().isEmpty) {
      throw ApiException(422, 'clientName is required');
    }
    final minutes = int.parse('${specialist['slotMinutes']}');
    final end = start.add(Duration(minutes: minutes));

    if (holdId == null && !_raceSimulated) {
      _raceSimulated = true;
      _bookings.add(_booking('race', specialistId, start, end));
      throw ApiException(409, 'Slot already taken');
    }

    if (_hasOverlap(specialistId, start, end, ignoreBookingId: holdId)) {
      throw ApiException(409, 'Slot already taken');
    }

    if (holdId != null) {
      _bookings.removeWhere(
        (b) => b['id'] == holdId && b['status'] == 'pending',
      );
    }

    final booking = _booking(
      'b${_now().microsecondsSinceEpoch}',
      specialistId,
      start,
      end,
      clientName: clientName.trim(),
    );
    _bookings.add(booking);
    return _copy(booking);
  }

  // ---------------------------------------------------------------------------

  Map<String, dynamic> _findSpecialist(String specialistId) =>
      _specialists.firstWhere(
        (s) => s['id'] == specialistId,
        orElse: () => throw ApiException(422, 'Unknown specialist'),
      );

  void _purgeExpiredHolds() {
    final now = _now();
    _bookings.removeWhere((b) {
      if (b['status'] != 'pending') return false;
      final rawExpiresAt = b['expiresAt'] as String?;
      if (rawExpiresAt == null) return true;
      return !DateTime.parse(rawExpiresAt).isAfter(now);
    });
  }

  bool _hasOverlap(
    String specialistId,
    DateTime start,
    DateTime end, {
    String? ignoreBookingId,
  }) {
    return _bookings.any((b) {
      if (b['specialistId'] != specialistId) return false;
      if (ignoreBookingId != null && b['id'] == ignoreBookingId) return false;
      final status = b['status'];
      if (status != 'active' && status != 'pending') return false;
      final bStart = DateTime.parse(b['start'] as String);
      final bEnd = DateTime.parse(b['end'] as String);
      return start.isBefore(bEnd) && end.isAfter(bStart);
    });
  }

  Future<void> _network() async {
    await Future<void>.delayed(latency);
    _requests++;
    if (_requests % 4 == 0) {
      throw ApiException(503, 'Service unavailable');
    }
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> m) =>
      Map<String, dynamic>.from(m);

  static Map<String, dynamic> _booking(
    String id,
    String specialistId,
    DateTime start,
    DateTime end, {
    String status = 'active',
    String? clientName,
    DateTime? expiresAt,
  }) =>
      {
        'id': id,
        'specialistId': specialistId,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'status': status,
        'clientName': ?clientName,
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
      };

  List<Map<String, dynamic>> _seedSpecialists() {
    const weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    Map<String, dynamic> hours(List<String>? weekday, {List<String>? sat}) => {
          for (final d in weekdays)
            d: d == 'sun'
                ? null
                : d == 'sat'
                    ? sat
                    : weekday,
        };

    final specialists = <Map<String, dynamic>>[
      {
        'id': 's1',
        'name': 'Олена',
        'service': 'Стрижка',
        'slotMinutes': 30,
        'workingHours': hours(['09:00', '18:00'], sat: ['10:00', '15:00']),
        'break': {'start': '13:00', 'end': '14:00'},
      },
      {
        'id': 's2',
        'name': 'Ігор',
        'service': 'Масаж',
        'slotMinutes': '60',
        'workingHours': hours(['10:00', '20:00']),
        'break': null,
      },
      {
        'id': 's3',
        'name': 'Марія',
        'service': 'Манікюр',
        'slotMinutes': 45,
        'workingHours': hours(['09:00', '17:30'], sat: ['09:00', '14:00']),
        'break': {'start': '12:30', 'end': '13:15'},
      },
    ];

    if (scenario == ApiScenario.incident) {
      
      final todayKey = weekdays[DateTime.now().weekday - 1];
      (specialists[0]['workingHours'] as Map<String, dynamic>)[todayKey] = null;
     
      specialists.add({
        'id': 's4',
        'name': 'Макс',
        'service': 'Тату',
        'slotMinutes': 90,
        'workingHours': {for (final d in weekdays) d: ['18:00', '00:00']},
        'break': null,
      });
    }
    return specialists;
  }

  List<Map<String, dynamic>> _seedBookings() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime at(int day, int h, [int m = 0]) =>
        today.add(Duration(days: day, hours: h, minutes: m));

    final bookings = <Map<String, dynamic>>[
      
      _booking('b3', 's1', at(0, 15), at(0, 16, 30)),
      _booking('b1', 's1', at(0, 10, 15), at(0, 11)),
      _booking('b2', 's1', at(0, 11), at(0, 11, 30), status: 'cancelled'),
      _booking('b1', 's1', at(0, 10, 15), at(0, 11)), // дубль
      _booking('b4', 's1', at(1, 9), at(1, 9, 30)),
      _booking('b5', 's2', at(0, 12), at(0, 13)),
      _booking('b6', 's2', at(1, 10), at(1, 11)),
      _booking('b7', 's3', at(0, 9, 45), at(0, 10, 30)),
      _booking('b8', 's3', at(1, 16), at(1, 16, 45)),
    ];

    if (scenario == ApiScenario.incident) {
      
      bookings.add(_booking('b9', 's4', at(0, 23, 30), at(1, 0, 30)));
      bookings.add(_booking('b10', 's4', at(0, 19), at(0, 20, 30)));
    }
    return bookings;
  }
}
