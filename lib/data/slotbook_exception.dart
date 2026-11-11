sealed class SlotBookException implements Exception {
  const SlotBookException(this.userMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}

final class ServiceUnavailableException extends SlotBookException {
  const ServiceUnavailableException()
      : super('Сервіс тимчасово недоступний. Спробуйте ще раз.');
}

final class SlotConflictException extends SlotBookException {
  const SlotConflictException()
      : super('Цей час щойно зайняли. Список слотів оновлено.');
}

final class ValidationException extends SlotBookException {
  const ValidationException(super.userMessage);
}

final class UnexpectedApiException extends SlotBookException {
  const UnexpectedApiException([
    super.userMessage = 'Сталася непередбачена помилка. Спробуйте пізніше.',
  ]);
}
