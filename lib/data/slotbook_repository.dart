import 'package:livecoding/api/slotbook_api.dart';
import 'package:livecoding/data/slotbook_exception.dart';
import 'package:livecoding/data/slotbook_mapper.dart';
import 'package:livecoding/models/booking.dart';
import 'package:livecoding/models/specialist.dart';
import 'package:livecoding/services/booking_storage_service.dart';
import 'package:livecoding/services/error_logger_service.dart';

abstract interface class SlotBookRepository {
  Future<List<Specialist>> getSpecialists();

  Future<List<Booking>> getBookings(String specialistId, DateTime day);

  Future<Booking> holdSlot({
    required String specialistId,
    required DateTime start,
  });

  Future<void> releaseHold(String holdId);

  Future<Booking> createBooking({
    required String specialistId,
    required DateTime start,
    required String clientName,
    String? holdId,
  });

  Future<List<Booking>> getSavedBookings();
}

class ApiSlotBookRepository implements SlotBookRepository {
  ApiSlotBookRepository(
    this._api, {
    BookingStorageService? storage,
    ErrorLoggerService? errorLogger,
    int maxUnavailableRetries = 1,
    Duration retryDelay = Duration.zero,
  })  : _storage = storage ?? InMemoryBookingStorageService(),
        _errorLogger = errorLogger ?? AppErrorLoggerService(),
        _maxUnavailableRetries = maxUnavailableRetries,
        _retryDelay = retryDelay;

  final SlotBookApi _api;
  final BookingStorageService _storage;
  final ErrorLoggerService _errorLogger;
  final int _maxUnavailableRetries;
  final Duration _retryDelay;

  @override
  Future<List<Specialist>> getSpecialists() => _guard(
        operation: 'getSpecialists',
        action: () async {
          final raw = await _api.getSpecialists();
          return raw.map(SlotBookMapper.specialistFromMap).toList();
        },
      );

  @override
  Future<List<Booking>> getBookings(String specialistId, DateTime day) =>
      _guard(
        operation: 'getBookings',
        context: {
          'specialistId': specialistId,
          'day': day.toIso8601String(),
        },
        action: () async {
          final raw = await _api.getBookings(specialistId, day);
          final normalized = SlotBookMapper.normalizeBookings(raw);
          await _syncDayPendingHolds(specialistId, day, normalized);
          await _storage.saveAll(normalized);
          return _storage.getBookingsFor(specialistId, day);
        },
      );

  @override
  Future<Booking> holdSlot({
    required String specialistId,
    required DateTime start,
  }) =>
      _guard(
        operation: 'holdSlot',
        context: {
          'specialistId': specialistId,
          'start': start.toIso8601String(),
        },
        action: () async {
          final raw = await _api.holdSlot(
            specialistId: specialistId,
            start: start,
          );
          final hold = SlotBookMapper.bookingFromMap(raw);
          await _storage.saveBooking(hold);
          _errorLogger.logBreadcrumb(
            'Slot hold acquired',
            data: {'holdId': hold.id, 'specialistId': hold.specialistId},
          );
          return hold;
        },
      );

  @override
  Future<void> releaseHold(String holdId) => _guard(
        operation: 'releaseHold',
        context: {'holdId': holdId},
        action: () async {
          await _api.releaseHold(holdId);
          await _storage.deleteById(holdId);
          _errorLogger.logBreadcrumb(
            'Slot hold released',
            data: {'holdId': holdId},
          );
        },
      );

  @override
  Future<Booking> createBooking({
    required String specialistId,
    required DateTime start,
    required String clientName,
    String? holdId,
  }) =>
      _guard(
        operation: 'createBooking',
        context: {
          'specialistId': specialistId,
          'start': start.toIso8601String(),
          'holdId': holdId,
        },
        action: () async {
          final trimmedName = clientName.trim();
          final raw = await _api.createBooking(
            specialistId: specialistId,
            start: start,
            clientName: trimmedName,
            holdId: holdId,
          );
          final parsed = SlotBookMapper.bookingFromMap(raw);
          final saved = parsed.clientName == null
              ? parsed.copyWith(clientName: trimmedName)
              : parsed;
          if (holdId != null) {
            await _storage.deleteById(holdId);
          }
          await _storage.saveBooking(saved);
          _errorLogger.logBreadcrumb(
            'Booking saved to local DB',
            data: {'id': saved.id, 'specialistId': saved.specialistId},
          );
          return saved;
        },
      );

  @override
  Future<List<Booking>> getSavedBookings() => _storage.getAllBookings();

  Future<void> _syncDayPendingHolds(
    String specialistId,
    DateTime day,
    List<Booking> fresh,
  ) async {
    final freshIds = fresh.map((b) => b.id).toSet();
    final stored = await _storage.getBookingsFor(specialistId, day);
    for (final existing in stored) {
      if (existing.isPending && !freshIds.contains(existing.id)) {
        await _storage.deleteById(existing.id);
      }
    }
  }

  Future<T> _guard<T>({
    required String operation,
    required Future<T> Function() action,
    Map<String, Object?> context = const {},
  }) async {
    _errorLogger.setCustomKey('last_api_operation', operation);
    var attempt = 0;
    while (true) {
      try {
        final result = await action();
        _errorLogger.setCustomKey('last_api_status', 200);
        return result;
      } on ApiException catch (e, st) {
        _errorLogger.setCustomKey('last_api_status', e.statusCode);
        if (e.statusCode == 503 && attempt < _maxUnavailableRetries) {
          attempt++;
          _errorLogger.logError(
            e,
            st,
            reason: '$operation: transient 503, retrying ($attempt)',
            context: {...context, 'statusCode': e.statusCode},
          );
          if (_retryDelay > Duration.zero) {
            await Future<void>.delayed(_retryDelay);
          }
          continue;
        }
        _errorLogger.logError(
          e,
          st,
          reason: '$operation failed with status ${e.statusCode}',
          context: {...context, 'statusCode': e.statusCode},
        );
        throw _mapApiException(e);
      } on FormatException catch (e, st) {
        _errorLogger
          ..setCustomKey('last_api_status', 'format_error')
          ..logError(
            e,
            st,
            reason: '$operation failed to parse response',
            context: context,
          );
        throw const UnexpectedApiException(
          'Отримано некоректні дані від сервера.',
        );
      }
    }
  }

  SlotBookException _mapApiException(ApiException error) {
    return switch (error.statusCode) {
      503 => const ServiceUnavailableException(),
      409 => const SlotConflictException(),
      422 => ValidationException(_mapValidationMessage(error.message)),
      _ => const UnexpectedApiException(),
    };
  }

  String _mapValidationMessage(String raw) {
    final normalized = raw.toLowerCase();
    if (normalized.contains('clientname')) {
      return 'Введіть імʼя клієнта.';
    }
    if (normalized.contains('specialist')) {
      return 'Обраного фахівця не знайдено.';
    }
    return 'Перевірте коректність даних для запису.';
  }
}
