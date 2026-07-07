import 'package:flutter_test/flutter_test.dart';
import 'package:knust_shuttle_connect/core/utils/phone_utils.dart';

void main() {
  group('normalizeGhanaPhone', () {
    test('converts local 0-prefixed numbers to +233', () {
      expect(normalizeGhanaPhone('0551234567'), '+233551234567');
      expect(normalizeGhanaPhone('055 123 4567'), '+233551234567');
      expect(normalizeGhanaPhone('055-123-4567'), '+233551234567');
    });

    test('passes through valid international numbers', () {
      expect(normalizeGhanaPhone('+233551234567'), '+233551234567');
    });

    test('rejects invalid input', () {
      expect(normalizeGhanaPhone('12345'), isNull);
      expect(normalizeGhanaPhone('055123'), isNull);
      expect(normalizeGhanaPhone('not a number'), isNull);
      expect(normalizeGhanaPhone('+12'), isNull);
    });
  });
}
