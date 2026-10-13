import 'package:flutter_test/flutter_test.dart';
import 'package:campus_notify/core/format.dart';

void main() {
  group('formatDateTime', () {
    test('formats day, month, year and time with padding', () {
      expect(formatDateTime(DateTime(2026, 10, 4, 8, 5)), '04 Okt 2026 08:05');
      expect(formatDateTime(DateTime(2026, 1, 14, 13, 0)), '14 Jan 2026 13:00');
    });

    test('uses Indonesian month abbreviations', () {
      expect(formatDateTime(DateTime(2026, 12, 31, 23, 59)), '31 Des 2026 23:59');
    });
  });

  group('routeFromMessage', () {
    test('defaults to / when payload is empty', () {
      expect(routeFromMessage({}), '/');
      expect(routeFromMessage({'route': ''}), '/');
    });

    test('normalizes slash-less routes', () {
      expect(routeFromMessage({'route': 'announcement/3'}), '/announcement/3');
    });

    test('keeps routes that already start with slash', () {
      expect(routeFromMessage({'route': '/announcement/3'}), '/announcement/3');
    });
  });
}
