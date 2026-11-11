import 'package:livecoding/api/slotbook_api.dart';
import 'package:livecoding/models/booking.dart';
import 'package:livecoding/models/specialist.dart';
import 'package:livecoding/models/time_slot.dart';

enum LoadStatus {
  initial,
  loading,
  loaded,
  error,
}

class BookingState {
  const BookingState({
    required this.selectedDay,
    required this.availableDays,
    this.specialistsStatus = LoadStatus.initial,
    this.specialists = const [],
    this.specialistsError,
    this.selectedSpecialist,
    this.slotsStatus = LoadStatus.initial,
    this.slots = const [],
    this.slotsError,
    this.isDayOff = false,
    this.isHoldingSlot = false,
    this.activeHold,
    this.isSubmitting = false,
    this.bookingError,
    this.isBookingConflict = false,
    this.notificationsEnabled = true,
    this.showUnavailableSlots = true,
    this.scenario = ApiScenario.normal,
    this.lastConfirmedMessage,
    this.savedBookings = const [],
  });

  static const Object _unset = Object();

  final LoadStatus specialistsStatus;
  final List<Specialist> specialists;
  final String? specialistsError;

  final Specialist? selectedSpecialist;
  final DateTime selectedDay;
  final List<DateTime> availableDays;

  final LoadStatus slotsStatus;
  final List<TimeSlot> slots;
  final String? slotsError;
  final bool isDayOff;

  final bool isHoldingSlot;
  final Booking? activeHold;

  final bool isSubmitting;
  final String? bookingError;
  final bool isBookingConflict;

  final bool notificationsEnabled;
  final bool showUnavailableSlots;
  final ApiScenario scenario;
  final String? lastConfirmedMessage;
  final List<Booking> savedBookings;

  int get availableSlotsCount =>
      slots.where((slot) => slot.isAvailable).length;

  List<Booking> get clientBookings => savedBookings
      .where(
        (b) => b.isActive && b.clientName != null && b.clientName!.isNotEmpty,
      )
      .toList();

  BookingState copyWith({
    LoadStatus? specialistsStatus,
    List<Specialist>? specialists,
    Object? specialistsError = _unset,
    Object? selectedSpecialist = _unset,
    DateTime? selectedDay,
    List<DateTime>? availableDays,
    LoadStatus? slotsStatus,
    List<TimeSlot>? slots,
    Object? slotsError = _unset,
    bool? isDayOff,
    bool? isHoldingSlot,
    Object? activeHold = _unset,
    bool? isSubmitting,
    Object? bookingError = _unset,
    bool? isBookingConflict,
    bool? notificationsEnabled,
    bool? showUnavailableSlots,
    ApiScenario? scenario,
    Object? lastConfirmedMessage = _unset,
    List<Booking>? savedBookings,
  }) {
    return BookingState(
      specialistsStatus: specialistsStatus ?? this.specialistsStatus,
      specialists: specialists ?? this.specialists,
      specialistsError: identical(specialistsError, _unset)
          ? this.specialistsError
          : specialistsError as String?,
      selectedSpecialist: identical(selectedSpecialist, _unset)
          ? this.selectedSpecialist
          : selectedSpecialist as Specialist?,
      selectedDay: selectedDay ?? this.selectedDay,
      availableDays: availableDays ?? this.availableDays,
      slotsStatus: slotsStatus ?? this.slotsStatus,
      slots: slots ?? this.slots,
      slotsError: identical(slotsError, _unset)
          ? this.slotsError
          : slotsError as String?,
      isDayOff: isDayOff ?? this.isDayOff,
      isHoldingSlot: isHoldingSlot ?? this.isHoldingSlot,
      activeHold: identical(activeHold, _unset)
          ? this.activeHold
          : activeHold as Booking?,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      bookingError: identical(bookingError, _unset)
          ? this.bookingError
          : bookingError as String?,
      isBookingConflict: isBookingConflict ?? this.isBookingConflict,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      showUnavailableSlots: showUnavailableSlots ?? this.showUnavailableSlots,
      scenario: scenario ?? this.scenario,
      lastConfirmedMessage: identical(lastConfirmedMessage, _unset)
          ? this.lastConfirmedMessage
          : lastConfirmedMessage as String?,
      savedBookings: savedBookings ?? this.savedBookings,
    );
  }
}
