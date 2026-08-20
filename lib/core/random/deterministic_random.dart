/// Small, explicitly seeded xorshift32 generator.
///
/// The 32-bit state is intentional: it remains bit-for-bit deterministic in
/// Dart VM and JavaScript builds, unlike algorithms that depend on 64-bit
/// integer behavior.
class DeterministicRandom {
  DeterministicRandom(int seed) : _state = _normalize(seed);

  int _state;

  static int _normalize(int seed) {
    final value = seed & 0xffffffff;
    return value == 0 ? 0x6d2b79f5 : value;
  }

  /// Returns the low 32 bits of [first] × [second] without relying on a
  /// potentially imprecise 64-bit intermediate in JavaScript builds.
  static int multiplyUint32(int first, int second) {
    final firstLow = first & 0xffff;
    final firstHigh = (first >>> 16) & 0xffff;
    final secondLow = second & 0xffff;
    final secondHigh = (second >>> 16) & 0xffff;
    return (firstLow * secondLow +
            ((firstHigh * secondLow + firstLow * secondHigh) << 16)) &
        0xffffffff;
  }

  int nextUint32() {
    var value = _state;
    value ^= (value << 13) & 0xffffffff;
    value ^= value >>> 17;
    value ^= (value << 5) & 0xffffffff;
    _state = value & 0xffffffff;
    return _state;
  }

  double nextDouble() => nextUint32() / 0x100000000;

  bool nextBool([double probability = 0.5]) => nextDouble() < probability;

  int nextInt(int max) {
    if (max <= 0) throw RangeError.range(max, 1, null, 'max');
    return (nextDouble() * max).floor();
  }

  double between(double min, double max) => min + (max - min) * nextDouble();

  T choose<T>(List<T> values) {
    if (values.isEmpty) throw StateError('Cannot choose from an empty list.');
    return values[nextInt(values.length)];
  }

  void shuffle<T>(List<T> values) {
    for (var index = values.length - 1; index > 0; index--) {
      final swapIndex = nextInt(index + 1);
      final value = values[index];
      values[index] = values[swapIndex];
      values[swapIndex] = value;
    }
  }

  DeterministicRandom fork(int salt) =>
      DeterministicRandom(nextUint32() ^ multiplyUint32(salt, 0x9e3779b9));
}
