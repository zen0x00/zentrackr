import 'package:flutter_test/flutter_test.dart';
import 'package:zentrackr/core/metrics.dart';

void main() {
  group('weight conversion', () {
    test('round trips pounds', () {
      expect(
        canonicalWeight(displayWeight(100, 'lb'), 'lb'),
        closeTo(100, 0.0001),
      );
    });
    test('keeps kilograms unchanged', () {
      expect(canonicalWeight(82.5, 'kg'), 82.5);
      expect(displayWeight(82.5, 'kg'), 82.5);
    });
  });

  test('effort validation follows the selected scale', () {
    expect(validEffort(8.5, 'rpe'), isTrue);
    expect(validEffort(8.25, 'rpe'), isFalse);
    expect(validEffort(2, 'rir'), isTrue);
    expect(validEffort(2.5, 'rir'), isFalse);
  });
}
