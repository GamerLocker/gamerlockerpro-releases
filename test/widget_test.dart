import 'package:flutter_test/flutter_test.dart';
import 'package:steamvault2/main.dart';

void main() {
  group('Premier Rating', () {
    test('formata 15000 como 15K', () {
      expect(formatPremierRating('15000'), '15K');
    });

    test('mantém 15K', () {
      expect(formatPremierRating('15K'), '15K');
    });

    test('formata 21500 como 21.5K', () {
      expect(formatPremierRating('21500'), '21.5K');
    });

    test('formata 13.000 como 13K', () {
      expect(formatPremierRating('13.000'), '13K');
    });

    test('aceita 14,5K', () {
      expect(formatPremierRating('14,5K'), '14.5K');
    });
  });
}
