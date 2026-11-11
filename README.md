# SlotBook — Flutter Slot-Booking App

A client-side Flutter appointment booking app built during a live-coding sprint, focused on resilient business logic, transient network fault handling, race-condition protection, and observability via Firebase Crashlytics.

---

## Tech Stack

- **Flutter / Dart** (`sdk: ^3.11.3`)
- **State management:** `flutter_bloc` (`BookingCubit`, `BookingState`)
- **Navigation:** `go_router` (`StatefulShellRoute.indexedStack` with 3 branches)
- **Monitoring & crash reporting:** `firebase_core`, `firebase_crashlytics` (`AppCrashMonitor`)
- **Static analysis:** `very_good_analysis`

---

## Project Architecture

```text
lib/
├── api/            # SlotBookApi (mock backend with ApiScenario.normal / incident, 503, 409, 422, pending holds)
├── data/           # SlotBookRepository, SlotBookMapper, typed SlotBookException hierarchy
├── logic/          # Pure Dart business logic: SlotGenerator, ClientNameValidator
├── models/         # Specialist, Booking (active / pending / cancelled), TimeRange, TimeSlot
├── services/       # InMemoryBookingStorageService, AppErrorLoggerService, AppCrashMonitor
├── state/          # BookingCubit, BookingState
└── ui/             # Screens (Home, Booking/Slots, Settings), BookingSheet, MemoryDebugSheet, GoRouter
```

---

## Work Completed

### 1. Resilience to Unstable APIs & Inconsistent Payloads
- Implemented silent retries for transient `503 Service Unavailable` responses in [`ApiSlotBookRepository`](lib/data/slotbook_repository.dart), while immediately surfacing non-retryable client errors (`409 Conflict`, `422 Validation`).
- Added defensive payload normalization in [`SlotBookMapper`](lib/data/slotbook_mapper.dart): handling mixed `slotMinutes` types (`int` and `String`), deduplicating bookings by `id`, converting UTC timestamps to local time, and treating `'00:00'` shift ends as end-of-day (`+1 day`).

### 2. Race-Condition Protection & `pending` Slot Holds
- Added temporary slot reservation (`holdSlot` / `releaseHold` with `pending` status and a `2`-minute TTL in [`SlotBookApi`](lib/api/slotbook_api.dart)):
  - opening [`BookingSheet`](lib/ui/widgets/booking_sheet.dart) immediately reserves the selected slot via `acquireHold`;
  - dismissing the sheet without confirming automatically releases the hold via `releaseActiveHold`;
  - confirming converts `holdId` into an `active` booking with `clientName`.
- Guarded [`BookingCubit.loadSlots`](lib/state/booking_cubit.dart) with a `_slotsRequestId` sequence counter so slow responses from previously selected days or specialists cannot overwrite newer selections.

### 3. Local Storage, Input Validation & Error Logging
- Built [`InMemoryBookingStorageService`](lib/services/booking_storage_service.dart) to persist bookings (including `clientName`) and keep local state synchronized with server-side `pending` holds.
- Implemented [`ClientNameValidator`](lib/logic/client_name_validator.dart) enforcing non-empty input, max length (`40` characters), and valid Unicode letters, spaces, hyphens, and apostrophes.
- Added [`AppErrorLoggerService`](lib/services/error_logger_service.dart) to retain non-fatal error records and chronological breadcrumbs in memory.

### 4. Firebase Crashlytics Integration (`AppCrashMonitor`)
- Initialized `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` and wired global fatal handlers (`FlutterError.onError` and `PlatformDispatcher.instance.onError`) in [`main.dart`](lib/main.dart).
- Connected all core layers to [`AppCrashMonitor`](lib/services/app_crash_monitor.dart):
  - **Custom keys:** `scenario`, `current_screen`, `selected_day`, `selected_specialist_id`, `selected_specialist_name`, `specialist_slot_minutes`, `is_day_off`, `slots_count`, `available_slots_count`, `active_hold_id`, `last_api_operation`, `last_api_status`, `last_client_name`, `last_booking_id`, and more;
  - **Breadcrumbs (`log`):** screen navigation, specialist/day selection, slot calculation, opening/cancelling `BookingSheet`, hold conflicts, validation failures, and scenario toggles;
  - **User identifier (`setUserIdentifier`):** `'guest'` at startup and updated with the client name upon booking confirmation;
  - **Non-fatal / fatal reporting (`recordError`)** and a **Test Crash (`testCrash`)** action under Diagnostics in Settings.

### 5. Diagnostics & Test Coverage
- Added [`MemoryDebugSheet`](lib/ui/widgets/memory_debug_sheet.dart) to inspect runtime memory: generated slots, saved client bookings, recent logged errors, and live Crashlytics custom keys.
- Added an `ApiScenario.incident` / `ApiScenario.normal` toggle in [`SettingsScreen`](lib/ui/screens/settings_screen.dart) to manually reproduce incident edge cases (weekday sick leave for the default specialist and an evening `18:00–00:00` shift crossing midnight).
- Added and verified **21 tests** under `test/`:
  - [`slot_generator_test.dart`](test/slot_generator_test.dart) — 8 unit tests covering high-risk slot calculation edge cases (day off, partial trailing remainder slots, breaks with `includeBooked: true`, off-grid & multi-slot bookings, `cancelled` bookings, past/boundary slots, `18:00–00:00` shift + cross-midnight booking, and active vs. expired `pending` holds).
  - [`slots_screen_test.dart`](test/slots_screen_test.dart) — widget test for [`SlotsScreen`](lib/ui/screens/slots_screen.dart) with a fake repository (retry after `503`, day-off state, `BookingSheet` hold acquisition, client name validation, and successful booking).
  - [`slotbook_repository_test.dart`](test/slotbook_repository_test.dart), [`client_name_validator_test.dart`](test/client_name_validator_test.dart), and [`widget_test.dart`](test/widget_test.dart) covering retries, local DB persistence, error logging, name validation, and tab navigation.

---

## Getting Started & Verification

```bash
flutter pub get
flutter analyze
flutter test
```

Latest `flutter test` run: **21/21 tests passed**.

---

## Conclusions & Next Steps

1. **Idempotency keys on a real backend:** Silent retries are safe for idempotent reads, but `holdSlot` and `createBooking` in production should include an `Idempotency-Key` so retrying after a network timeout cannot duplicate records or cause false `409` conflicts.
2. **Early sheet dismissal during in-flight `acquireHold`:** Closing `BookingSheet` before `holdSlot` completes can leave a hold active until its `2`-minute TTL expires; a `dispose`-aware cancellation check should release the hold as soon as the in-flight request resolves.
3. **Hold countdown & DST safety:** Displaying the remaining hold time before `expiresAt` prevents stale submissions, and slot start/end calculation should account for daylight saving time transitions rather than relying solely on `dayStart.add(Duration(...))`.
4. **Narrow-screen layout polish:** Wrapping `Text(address)` in `Expanded` inside `_LocationRow` ([`BookingHeader`](lib/ui/widgets/booking_header.dart)) will prevent horizontal `RenderFlex` overflow on narrow devices or larger system font scales.
