abstract final class ClientNameValidator {
  static const int maxLength = 40;

  static final RegExp _namePattern = RegExp(
    r"^[\p{L}]+(?:[ '\-ʼ’][\p{L}]+)*$",
    unicode: true,
  );

  static String? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Введіть імʼя клієнта.';
    }
    if (trimmed.length > maxLength) {
      return 'Імʼя не може перевищувати $maxLength символів.';
    }
    if (!_namePattern.hasMatch(trimmed)) {
      return 'Імʼя може містити лише літери, пробіли, дефіс або апостроф.';
    }
    return null;
  }
}
