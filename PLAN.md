# План
- **Шари та класи**: `models` (`Specialist`, `TimeRange`, `Booking`, `TimeSlot`) нормалізують дані; `data` (`SlotBookRepository` над `SlotBookApi`) мапить відповіді й дедуплікує; `logic` (`SlotGenerator`) рахує слоти; `state` (`BookingController` на `ChangeNotifier`) і `ui` керують екраном.
- **Розрахунок слотів**: якщо `workingHours[weekday] == null` — день неробочий; інакше крокуємо по `slotMinutes` у межах `[workStart, workEnd]` (`'00:00'` у кінці трактуємо як `24:00`).
- **Перевірка зайнятості**: переводимо бронювання у `.toLocal()`, ігноруємо `cancelled`, а вільність визначаємо відсутністю перетину (`slotStart < end && slotEnd > start`) з `break` і `active`-бронюваннями та умовою `slotStart >= now`.
- **Помилки API**: кожен 4-й запит падає з `503` (retry/банер), перший `createBooking` симулює `409` race condition (перезавантаження слотів), `422` для порожнього `clientName` або невідомого `specialistId`.
- **Неконсистентна схема**: `slotMinutes` буває `int` і `String` (`'60'`), `break` і `workingHours[day]` бувають `null` (зокрема сьогодні у `incident`), нічна зміна `18:00–00:00`, часи у UTC.
- **Аномалії бронювань**: невідсортований список, дублі за `id`, скасовані (`cancelled`), некратні сітці та багатослотові (`10:15–11:00`, `15:00–16:30`), бронювання через північ (`23:30–00:30`).
