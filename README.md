# SlotBook — застосунок бронювання слотів на Flutter

Клієнтський Flutter-застосунок для запису до фахівців салону, розроблений у форматі лайвкодинг-спринту з фокусом на надійність бізнес-логіки, обробку мережевих збоїв, захист від гонок даних (race conditions) та спостережуваність через Firebase Crashlytics.

---

## Стек та ключові пакети

- **Flutter / Dart** (`sdk: ^3.11.3`)
- **State management:** `flutter_bloc` (`BookingCubit`, `BookingState`)
- **Навігація:** `go_router` (`StatefulShellRoute.indexedStack` із 3 гілками)
- **Моніторинг і краш-репортинг:** `firebase_core`, `firebase_crashlytics` (`AppCrashMonitor`)
- **Статичний аналіз:** `very_good_analysis`

---

## Архітектура проєкту

```text
lib/
├── api/            # SlotBookApi (мок-бекенд з ApiScenario.normal / incident, 503, 409, 422, pending hold)
├── data/           # SlotBookRepository, SlotBookMapper, типізовані винятки SlotBookException
├── logic/          # Чиста Dart-логіка: SlotGenerator, ClientNameValidator
├── models/         # Specialist, Booking (active / pending / cancelled), TimeRange, TimeSlot
├── services/       # InMemoryBookingStorageService, AppErrorLoggerService, AppCrashMonitor
├── state/          # BookingCubit, BookingState
└── ui/             # Екрани (Home, Booking/Slots, Settings), BookingSheet, MemoryDebugSheet, GoRouter
```

---

## Пророблена робота

### 1. Стійкість до нестабільного API та мережевих помилок
- Реалізовано тихий повторний запит (silent retry) при тимчасових помилках `503 Service Unavailable` в [`ApiSlotBookRepository`](lib/data/slotbook_repository.dart), без ретраю клієнтських помилок (`409 Conflict`, `422 Validation`).
- Додано мапінг різнотипних та брудних даних API у [`SlotBookMapper`](lib/data/slotbook_mapper.dart): підтримка `slotMinutes` як `int` і `String`, дедуплікація записів за `id`, конвертація UTC → local, обробка зміни до `'00:00'` як кінця доби (`+1 день`).

### 2. Захист від станів гонки (Race Conditions) та `pending`-холдів
- Впроваджено механізм тимчасового резервування слота (`holdSlot` / `releaseHold` зі статусом `pending` та TTL `2 хв` у [`SlotBookApi`](lib/api/slotbook_api.dart)):
  - при відкритті [`BookingSheet`](lib/ui/widgets/booking_sheet.dart) слот миттєво резервується на сервері через `acquireHold`;
  - якщо форму закрили без підтвердження — холд звільняється через `releaseActiveHold`;
  - при підтвердженні `holdId` атомарно конвертується в `active`-бронювання разом із `clientName`.
- Захищено [`BookingCubit.loadSlots`](lib/state/booking_cubit.dart) лічильником `_slotsRequestId`, щоб повільна відповідь від попереднього фахівця/дня не затирала актуальний стан при швидкому перемиканні.

### 3. Локальне збереження, валідація та логування
- Реалізовано [`InMemoryBookingStorageService`](lib/services/booking_storage_service.dart) для збереження записів із `clientName` та синхронізації з актуальним станом серверних `pending`-холдів.
- Створено [`ClientNameValidator`](lib/logic/client_name_validator.dart): перевірка на порожнє значення, обмеження довжини (до `40` символів) і дозволені Unicode-літери, пробіли, дефіс та апостроф.
- Налаштовано [`AppErrorLoggerService`](lib/services/error_logger_service.dart) для накопичення non-fatal помилок і breadcrumbs у памʼяті.

### 4. Інтеграція Firebase Crashlytics (`AppCrashMonitor`)
- Ініціалізовано `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` та глобальні перехоплювачі `FlutterError.onError` і `PlatformDispatcher.instance.onError` у [`main.dart`](lib/main.dart).
- Обгорнуто ключові шари застосунку функціями [`AppCrashMonitor`](lib/services/app_crash_monitor.dart):
  - **Custom keys:** `scenario`, `current_screen`, `selected_day`, `selected_specialist_id`, `selected_specialist_name`, `specialist_slot_minutes`, `is_day_off`, `slots_count`, `available_slots_count`, `active_hold_id`, `last_api_operation`, `last_api_status`, `last_client_name`, `last_booking_id` тощо;
  - **Breadcrumbs (`log`):** навігація, вибір фахівця/дня, завантаження слотів, відкриття/скасування `BookingSheet`, конфлікти та валідація;
  - **User identifier (`setUserIdentifier`):** `'guest'` за замовчуванням та імʼя клієнта після запису;
  - **Non-fatal / fatal errors (`recordError`)** та **Тестовий краш (`testCrash`)** у розділі «Діагностика» на екрані налаштувань.

### 5. Інструменти діагностики та тестове покриття
- Додано [`MemoryDebugSheet`](lib/ui/widgets/memory_debug_sheet.dart) для читання внутрішньої памʼяті в рантаймі: поточні слоти, збережені клієнти в БД, останні помилки та живий список Crashlytics-ключів.
- У [`SettingsScreen`](lib/ui/screens/settings_screen.dart) винесено перемикач `ApiScenario.incident` / `ApiScenario.normal` для ручного відтворення інцидент-кейсів (лікарняний Олени серед тижня, вечірня зміна Макса `18:00–00:00` через північ).
- Написано та перевірено **21 тест** у `test/`:
  - [`slot_generator_test.dart`](test/slot_generator_test.dart) — 8 unit-тестів для найризиковіших едж-кейсів розрахунку слотів (вихідний день, обрізаний кінець зміни, перерви при `includeBooked: true`, оф-грід і мультислотові бронювання, `cancelled`, минулі слоти, зміна `18:00–00:00` + крос-північний запис, активний та прострочений `pending`-холд).
  - [`slots_screen_test.dart`](test/slots_screen_test.dart) — widget-тест [`SlotsScreen`](lib/ui/screens/slots_screen.dart) із фейковим репозиторієм (retry після `503`, вихідний день, відкриття шторки з `holdSlot`, валідація імені, успішний запис).
  - [`slotbook_repository_test.dart`](test/slotbook_repository_test.dart), [`client_name_validator_test.dart`](test/client_name_validator_test.dart), [`widget_test.dart`](test/widget_test.dart) — перевірка ретраїв, локальної БД, логера, валідатора та навігації.

---

## Запуск і перевірка

```bash
flutter pub get
flutter analyze
flutter test
```

Останній прогін `flutter test`: **21/21 тестів пройдено успішно**.

---

## Висновки та що варто покращити далі

1. **Ідемпотентність на реальному бекенді:** автоматичний retry безпечний для GET-запитів, але для `holdSlot` і `createBooking` у продакшені потрібен `Idempotency-Key`, щоб повторний запит після таймауту не створював дублів.
2. **Раннє закриття шторки під час `acquireHold`:** якщо закрити `BookingSheet`, поки `holdSlot` ще виконується в мережі, холд може залишитись активним до завершення `2 хв` TTL — варто скасовувати/звільняти холд за фактом завершення `Future`, якщо sheet вже `disposed`.
3. **Таймер життя холда та DST:** у формі варто показувати відлік до `expiresAt`, а при обчисленні слотів — враховувати дні переходу на літній/зимовий час замість фіксованого `dayStart.add(Duration(...))`.
4. **Адаптивність вузьких екранів:** у `_LocationRow` ([`BookingHeader`](lib/ui/widgets/booking_header.dart)) варто огорнути `Text(address)` у `Expanded`, щоб уникнути горизонтального overflow при вузьких екранах або збільшеному системному шрифті.
