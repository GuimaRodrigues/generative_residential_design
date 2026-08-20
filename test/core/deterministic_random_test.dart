import 'package:flutter_test/flutter_test.dart';
import 'package:generative_residential_design/core/random/deterministic_random.dart';

void main() {
  test('xorshift32 has a stable known sequence', () {
    final random = DeterministicRandom(1);
    expect(List<int>.generate(3, (_) => random.nextUint32()), <int>[
      270369,
      67634689,
      2647435461,
    ]);
  });

  test('32-bit multiplication preserves low bits without a 64-bit product', () {
    expect(
      DeterministicRandom.multiplyUint32(0xffffffff, 0x9e3779b9),
      0x61c88647,
    );
    expect(
      DeterministicRandom.multiplyUint32(0xdeadbeef, 0x7feb352d),
      0xf3770b03,
    );
  });
}
