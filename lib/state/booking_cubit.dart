import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:livecoding/api/slotbook_api.dart';
import 'package:livecoding/data/slotbook_exception.dart';
import 'package:livecoding/data/slotbook_repository.dart';
import 'package:livecoding/logic/client_name_validator.dart';
import 'package:livecoding/logic/slot_generator.dart';
import 'package:livecoding/models/booking.dart';
import 'package:livecoding/models/specialist.dart';
import 'package:livecoding/models/time_slot.dart';
import 'package:livecoding/services/error_logger_service.dart';
import 'package:livecoding/state/booking_state.dart';

class BookingCubit extends Cubit<BookingState> {
  BookingCubit({
    required SlotBookRepository repository,
    SlotBookRepository Function(ApiScenario scenario)? repositoryFactory,
    SlotGenerator slotGenerator = const SlotGenerator(),
    ErrorLoggerService? errorLogger,
    DateTime Function()? clock,
    ApiScenario initialScenario = ApiScenario.normal,
  })  : _repository = repository,
        _repositoryFactory = repositoryFactory,
        _slotGenerator = slotGenerator,
        _errorLogger = errorLogger,
        _clock = clock ?? DateTime.now,
        super(
          BookingState(
            selectedDay: _dateOnly((clock ?? DateTime.now)()),
            availableDays: _buildDays((clock ?? DateTime.now)()),
            scenario: initialScenario,
          ),
        ) {
    _syncInitialCrashKeys();
  }

  SlotBookRepository _repository;
  final SlotBookRepository Function(ApiScenario scenario)? _repositoryFactory;
  final SlotGenerator _slotGenerator;
  final ErrorLoggerService? _errorLogger;
  final DateTime Function() _clock;

  List<Booking> _lastBookings = const [];
  int _slotsRequestId = 0;

  List<ErrorLogEntry> get loggedErrors {
    final logger = _errorLogger;
    if (logger is AppErrorLoggerService) {
      return logger.entries;
    }
    return const [];
  }

  Map<String, Object> get crashCustomKeys {
    final logger = _errorLogger;
    if (logger is AppErrorLoggerService) {
      return logger.customKeys;
    }
    return const {};
  }

  String? get crashUserId {
    final logger = _errorLogger;
    if (logger is AppErrorLoggerService) {
      return logger.userId;
    }
    return null;
  }

  bool get hasCrashMonitor {
    final logger = _errorLogger;
    return logger is AppErrorLoggerService && logger.hasCrashMonitor;
  }

  void setCurrentScreen(String screen) {
    _errorLogger
      ?..setCustomKey('current_screen', screen)
      ..logBreadcrumb('Screen opened', data: {'screen': screen});
  }

  void logBreadcrumb(
    String message, {
    Map<String, Object?> data = const {},
  }) {
    _errorLogger?.logBreadcrumb(message, data: data);
  }

  void triggerTestCrash() {
    _errorLogger?.logBreadcrumb('Manual test crash requested');
    _errorLogger?.testCrash();
  }

  void _syncInitialCrashKeys() {
    _errorLogger
      ?..setCustomKey('scenario', state.scenario.name)
      ..setCustomKey('selected_day', _formatDayKey(state.selectedDay))
      ..setCustomKey('notifications_enabled', state.notificationsEnabled)
      ..setCustomKey('show_unavailable_slots', state.showUnavailableSlots)
      ..setCustomKey('active_hold_id', 'none')
      ..setUserIdentifier('guest');
  }

  void _setSpecialistCrashKeys(Specialist? specialist) {
    _errorLogger
      ?..setCustomKey('selected_specialist_id', specialist?.id ?? 'none')
      ..setCustomKey('selected_specialist_name', specialist?.name ?? 'none')
      ..setCustomKey('specialist_slot_minutes', specialist?.slotMinutes ?? 0);
  }

  static String _formatDayKey(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$d';
  }

  Future<void> refreshSavedBookings() async {
    final savedBookings = await _repository.getSavedBookings();
    if (isClosed) return;
    emit(state.copyWith(savedBookings: savedBookings));
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static List<DateTime> _buildDays(DateTime now) {
    final start = _dateOnly(now);
    return List.generate(7, (index) => start.add(Duration(days: index)));
  }

  Future<void> loadSpecialists() async {
    emit(
      state.copyWith(
        specialistsStatus: LoadStatus.loading,
        specialistsError: null,
      ),
    );

    try {
      final specialists = await _repository.getSpecialists();
      final savedBookings = await _repository.getSavedBookings();
      if (isClosed) return;

      final selected = _resolveSelectedSpecialist(specialists);
      _setSpecialistCrashKeys(selected);
      _errorLogger
        ?..setCustomKey('specialists_count', specialists.length)
        ..setCustomKey('saved_bookings_count', savedBookings.length)
        ..logBreadcrumb(
          'Specialists loaded',
          data: {
            'count': specialists.length,
            'selectedId': selected?.id ?? 'none',
          },
        );
      emit(
        state.copyWith(
          specialistsStatus: LoadStatus.loaded,
          specialists: specialists,
          selectedSpecialist: selected,
          savedBookings: savedBookings,
        ),
      );

      if (selected != null) {
        await loadSlots();
      }
    } on SlotBookException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          specialistsStatus: LoadStatus.error,
          specialistsError: e.userMessage,
        ),
      );
    } on Exception catch (e, st) {
      _errorLogger?.logError(e, st, reason: 'BookingCubit.loadSpecialists');
      if (isClosed) return;
      emit(
        state.copyWith(
          specialistsStatus: LoadStatus.error,
          specialistsError:
              'Не вдалося завантажити фахівців. Спробуйте ще раз.',
        ),
      );
    }
  }

  Specialist? _resolveSelectedSpecialist(List<Specialist> specialists) {
    if (specialists.isEmpty) return null;
    final current = state.selectedSpecialist;
    if (current != null) {
      for (final item in specialists) {
        if (item.id == current.id) return item;
      }
    }
    return specialists.first;
  }

  Future<void> selectSpecialist(Specialist specialist) async {
    final days = _buildDays(_clock());
    final day = days.any((d) => _isSameDate(d, state.selectedDay))
        ? state.selectedDay
        : days.first;

    _setSpecialistCrashKeys(specialist);
    _errorLogger
      ?..setCustomKey('selected_day', _formatDayKey(day))
      ..logBreadcrumb(
        'Specialist selected',
        data: {'id': specialist.id, 'name': specialist.name},
      );

    emit(
      state.copyWith(
        selectedSpecialist: specialist,
        availableDays: days,
        selectedDay: day,
      ),
    );
    await loadSlots();
  }

  Future<void> selectDay(DateTime day) async {
    final normalized = _dateOnly(day);
    _errorLogger
      ?..setCustomKey('selected_day', _formatDayKey(normalized))
      ..logBreadcrumb('Day selected', data: {'day': _formatDayKey(normalized)});
    emit(state.copyWith(selectedDay: normalized));
    await loadSlots();
  }

  Future<void> loadSlots() async {
    final specialist = state.selectedSpecialist;
    if (specialist == null) return;

    final requestId = ++_slotsRequestId;
    emit(
      state.copyWith(
        slotsStatus: LoadStatus.loading,
        slotsError: null,
      ),
    );

    try {
      final bookings = await _repository.getBookings(
        specialist.id,
        state.selectedDay,
      );
      final savedBookings = await _repository.getSavedBookings();
      if (isClosed || requestId != _slotsRequestId) return;

      _lastBookings = bookings;
      final isDayOff = specialist.workingHoursFor(state.selectedDay) == null;
      final generated = _generateSlots(specialist, state.selectedDay, bookings);
      final availableCount = generated.where((s) => s.isAvailable).length;
      _errorLogger
        ?..setCustomKey('is_day_off', isDayOff)
        ..setCustomKey('slots_count', generated.length)
        ..setCustomKey('available_slots_count', availableCount)
        ..setCustomKey('saved_bookings_count', savedBookings.length)
        ..logBreadcrumb(
          'Slots calculated',
          data: {
            'specialistId': specialist.id,
            'day': _formatDayKey(state.selectedDay),
            'isDayOff': isDayOff,
            'available': availableCount,
            'total': generated.length,
          },
        );
      emit(
        state.copyWith(
          slotsStatus: LoadStatus.loaded,
          isDayOff: isDayOff,
          slots: generated,
          savedBookings: savedBookings,
        ),
      );
    } on SlotBookException catch (e) {
      if (isClosed || requestId != _slotsRequestId) return;
      emit(
        state.copyWith(
          slotsStatus: LoadStatus.error,
          slotsError: e.userMessage,
        ),
      );
    } on Exception catch (e, st) {
      _errorLogger?.logError(e, st, reason: 'BookingCubit.loadSlots');
      if (isClosed || requestId != _slotsRequestId) return;
      emit(
        state.copyWith(
          slotsStatus: LoadStatus.error,
          slotsError: 'Не вдалося завантажити слоти. Спробуйте ще раз.',
        ),
      );
    }
  }

  Future<void> acquireHold(TimeSlot slot) async {
    final specialist = state.selectedSpecialist;
    if (specialist == null) return;

    emit(
      state.copyWith(
        isHoldingSlot: true,
        activeHold: null,
        bookingError: null,
        isBookingConflict: false,
      ),
    );

    try {
      final hold = await _repository.holdSlot(
        specialistId: specialist.id,
        start: slot.start,
      );
      if (isClosed) return;

      _lastBookings = [..._lastBookings, hold];
      _errorLogger?.setCustomKey('active_hold_id', hold.id);
      emit(
        state.copyWith(
          isHoldingSlot: false,
          activeHold: hold,
          slots: _generateSlots(specialist, state.selectedDay, _lastBookings),
        ),
      );
    } on SlotConflictException catch (e) {
      if (isClosed) return;
      _errorLogger
        ?..setCustomKey('active_hold_id', 'conflict')
        ..logBreadcrumb(
          'Hold conflict',
          data: {'slotStart': slot.start.toIso8601String()},
        );
      emit(
        state.copyWith(
          isHoldingSlot: false,
          activeHold: null,
          bookingError: e.userMessage,
          isBookingConflict: true,
        ),
      );
      await loadSlots();
    } on SlotBookException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isHoldingSlot: false,
          activeHold: null,
          bookingError: e.userMessage,
          isBookingConflict: false,
        ),
      );
    } on Exception catch (e, st) {
      _errorLogger?.logError(e, st, reason: 'BookingCubit.acquireHold');
      if (isClosed) return;
      emit(
        state.copyWith(
          isHoldingSlot: false,
          activeHold: null,
          bookingError: 'Не вдалося зарезервувати слот. Спробуйте ще раз.',
          isBookingConflict: false,
        ),
      );
    }
  }

  Future<void> releaseActiveHold() async {
    final hold = state.activeHold;
    if (hold == null) return;

    if (!isClosed) {
      _errorLogger?.setCustomKey('active_hold_id', 'none');
      emit(state.copyWith(activeHold: null));
    }

    try {
      await _repository.releaseHold(hold.id);
      if (isClosed) return;
      _lastBookings = _lastBookings.where((b) => b.id != hold.id).toList();
      final specialist = state.selectedSpecialist;
      if (specialist != null) {
        emit(
          state.copyWith(
            slots: _generateSlots(specialist, state.selectedDay, _lastBookings),
          ),
        );
      }
    } on Exception catch (e, st) {
      _errorLogger?.logError(e, st, reason: 'BookingCubit.releaseActiveHold');
    }
  }

  Future<bool> bookSlot({
    required TimeSlot slot,
    required String clientName,
  }) async {
    final specialist = state.selectedSpecialist;
    if (specialist == null) return false;

    final trimmed = clientName.trim();
    final validationError = ClientNameValidator.validate(trimmed);
    if (validationError != null) {
      _errorLogger?.logBreadcrumb(
        'Booking validation error',
        data: {'reason': validationError},
      );
      emit(
        state.copyWith(
          bookingError: validationError,
          isBookingConflict: false,
        ),
      );
      return false;
    }

    _errorLogger
      ?..setUserIdentifier(trimmed)
      ..setCustomKey('last_client_name', trimmed);

    emit(
      state.copyWith(
        isSubmitting: true,
        bookingError: null,
        isBookingConflict: false,
      ),
    );

    final holdId = state.activeHold?.id;
    try {
      final booking = await _repository.createBooking(
        specialistId: specialist.id,
        start: slot.start,
        clientName: trimmed,
        holdId: holdId,
      );
      final savedBookings = await _repository.getSavedBookings();
      if (isClosed) return false;

      _lastBookings = [
        ..._lastBookings.where((b) => b.id != holdId),
        booking,
      ];
      final updatedSlots = _generateSlots(
        specialist,
        state.selectedDay,
        _lastBookings,
      );
      _errorLogger
        ?..setCustomKey('active_hold_id', 'none')
        ..setCustomKey('last_booking_id', booking.id)
        ..setCustomKey('saved_bookings_count', savedBookings.length)
        ..setCustomKey('slots_count', updatedSlots.length);
      emit(
        state.copyWith(
          isSubmitting: false,
          activeHold: null,
          slots: updatedSlots,
          savedBookings: savedBookings,
          lastConfirmedMessage:
              '${booking.clientName ?? trimmed} · ${specialist.name}',
        ),
      );
      return true;
    } on SlotConflictException catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSubmitting: false,
          activeHold: null,
          bookingError: e.userMessage,
          isBookingConflict: true,
        ),
      );
      await loadSlots();
      return false;
    } on SlotBookException catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSubmitting: false,
          bookingError: e.userMessage,
          isBookingConflict: false,
        ),
      );
      return false;
    } on Exception catch (e, st) {
      _errorLogger?.logError(e, st, reason: 'BookingCubit.bookSlot');
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSubmitting: false,
          bookingError: 'Не вдалося створити запис. Спробуйте ще раз.',
          isBookingConflict: false,
        ),
      );
      return false;
    }
  }

  void clearBookingError() {
    if (state.bookingError == null && !state.isBookingConflict) return;
    emit(state.copyWith(bookingError: null, isBookingConflict: false));
  }

  void setNotificationsEnabled({required bool value}) {
    _errorLogger
      ?..setCustomKey('notifications_enabled', value)
      ..logBreadcrumb('Notifications toggled', data: {'enabled': value});
    emit(state.copyWith(notificationsEnabled: value));
  }

  void setShowUnavailableSlots({required bool value}) {
    final specialist = state.selectedSpecialist;
    final regenerated = specialist == null
        ? state.slots
        : _slotGenerator.generate(
            specialist: specialist,
            day: state.selectedDay,
            bookings: _lastBookings,
            now: _clock(),
            includeBooked: value,
          );
    _errorLogger
      ?..setCustomKey('show_unavailable_slots', value)
      ..setCustomKey('slots_count', regenerated.length)
      ..logBreadcrumb(
        'Unavailable slots visibility changed',
        data: {'visible': value},
      );
    emit(
      state.copyWith(
        showUnavailableSlots: value,
        slots: regenerated,
      ),
    );
  }

  Future<void> setScenario(ApiScenario scenario) async {
    if (_repositoryFactory == null || state.scenario == scenario) return;
    _repository = _repositoryFactory(scenario);
    _lastBookings = const [];
    _errorLogger
      ?..setCustomKey('scenario', scenario.name)
      ..setCustomKey('active_hold_id', 'none')
      ..logBreadcrumb(
        'API scenario switched',
        data: {'scenario': scenario.name},
      );
    emit(
      state.copyWith(
        scenario: scenario,
        selectedSpecialist: null,
        activeHold: null,
      ),
    );
    await loadSpecialists();
  }

  List<TimeSlot> _generateSlots(
    Specialist specialist,
    DateTime day,
    List<Booking> bookings,
  ) {
    return _slotGenerator.generate(
      specialist: specialist,
      day: day,
      bookings: bookings,
      now: _clock(),
      includeBooked: state.showUnavailableSlots,
    );
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
