class Size2D {
  const Size2D(this.width, this.height);

  final double width;
  final double height;

  double get area => width * height;

  @override
  bool operator ==(Object other) =>
      other is Size2D && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}
