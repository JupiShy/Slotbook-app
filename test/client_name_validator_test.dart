import 'package:flutter_test/flutter_test.dart';

import 'package:livecoding/logic/client_name_validator.dart';

void main() {
  group('ClientNameValidator', () {
    test('accepts valid Ukrainian and Latin names', () {
      expect(ClientNameValidator.validate('Анна'), isNull);
      expect(ClientNameValidator.validate('Олена Коваль'), isNull);
      expect(ClientNameValidator.validate('Анна-Марія'), isNull);
      expect(ClientNameValidator.validate('Марʼяна'), isNull);
      expect(ClientNameValidator.validate("Д'Артаньян"), isNull);
      expect(ClientNameValidator.validate('John Doe'), isNull);
    });

    test('rejects empty or whitespace-only names', () {
      expect(ClientNameValidator.validate(''), isNotNull);
      expect(ClientNameValidator.validate('   '), isNotNull);
    });

    test('rejects digits and special symbols', () {
      expect(ClientNameValidator.validate('Анна1'), isNotNull);
      expect(ClientNameValidator.validate('12345'), isNotNull);
      expect(ClientNameValidator.validate('Анна!'), isNotNull);
      expect(ClientNameValidator.validate('@anna'), isNotNull);
    });

    test('rejects names longer than maxLength', () {
      final exact = 'А' * ClientNameValidator.maxLength;
      final tooLong = 'А' * (ClientNameValidator.maxLength + 1);
      expect(ClientNameValidator.validate(exact), isNull);
      expect(ClientNameValidator.validate(tooLong), isNotNull);
    });
  });
}
