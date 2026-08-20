import 'package:flutter_test/flutter_test.dart';
import 'package:generative_residential_design/domain/site/site.dart';

void main() {
  Site site(StreetSide side) => Site(
    width: 12,
    depth: 30,
    streetSide: side,
    frontSetback: 5,
    rearSetback: 3,
    leftSetback: 1,
    rightSetback: 2,
  );

  test('south-facing envelope uses front at the south edge', () {
    final envelope = site(StreetSide.south).buildableEnvelope;
    expect(envelope.x, 1);
    expect(envelope.y, 3);
    expect(envelope.width, 9);
    expect(envelope.height, 22);
  });

  test('north-facing envelope rotates left and right setbacks', () {
    final envelope = site(StreetSide.north).buildableEnvelope;
    expect(envelope.x, 2);
    expect(envelope.y, 5);
    expect(envelope.width, 9);
    expect(envelope.height, 22);
  });

  test('east and west orientations map all setbacks', () {
    expect(site(StreetSide.east).buildableEnvelope.toJson(), <String, Object>{
      'x': 3.0,
      'y': 1.0,
      'width': 4.0,
      'height': 27.0,
    });
    expect(site(StreetSide.west).buildableEnvelope.toJson(), <String, Object>{
      'x': 5.0,
      'y': 2.0,
      'width': 4.0,
      'height': 27.0,
    });
  });

  test('invalid setbacks report an unusable envelope', () {
    final invalid = site(StreetSide.south)
        .copyWith(frontSetback: 20, rearSetback: 12);
    expect(invalid.validate(), isNotEmpty);
  });
}
