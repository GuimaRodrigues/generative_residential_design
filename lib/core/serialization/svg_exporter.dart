import '../../domain/design/design_candidate.dart';
import '../../domain/requirements/room_type.dart';
import '../../domain/site/site.dart';

class SvgExporter {
  const SvgExporter();

  String export({
    required DesignCandidate candidate,
    required Site site,
    required int floorIndex,
  }) {
    final floor = candidate.floors.firstWhere(
      (item) => item.floorIndex == floorIndex,
    );
    const scale = 45.0;
    const margin = 36.0;
    final width = site.width * scale + margin * 2;
    final height = site.depth * scale + margin * 2;
    double sx(double value) => margin + value * scale;
    double sy(double value) => margin + value * scale;
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" width="${width.toStringAsFixed(0)}" '
        'height="${height.toStringAsFixed(0)}" viewBox="0 0 ${width.toStringAsFixed(2)} ${height.toStringAsFixed(2)}">',
      )
      ..writeln('<rect width="100%" height="100%" fill="#F5F6F4"/>')
      ..writeln('<g font-family="Arial, sans-serif">')
      ..writeln(
        '<rect x="$margin" y="$margin" width="${site.width * scale}" '
        'height="${site.depth * scale}" fill="none" stroke="#27343A" stroke-width="2"/>',
      );
    final envelope = site.buildableEnvelope;
    buffer.writeln(
      '<rect x="${sx(envelope.x)}" y="${sy(envelope.y)}" '
      'width="${envelope.width * scale}" height="${envelope.height * scale}" '
      'fill="none" stroke="#79919A" stroke-width="1.5" stroke-dasharray="7 5"/>',
    );
    for (final room in floor.rooms) {
      final bounds = room.bounds;
      buffer
        ..writeln(
          '<rect x="${sx(bounds.x)}" y="${sy(bounds.y)}" '
          'width="${bounds.width * scale}" height="${bounds.height * scale}" '
          'fill="#E6ECE9" stroke="#233238" stroke-width="2"/>',
        )
        ..writeln(
          '<text x="${sx(bounds.center.x)}" y="${sy(bounds.center.y) - 4}" '
          'font-size="11" text-anchor="middle" fill="#172126" font-weight="700">'
          '${_escape(room.roomType.displayName.toUpperCase())}</text>',
        )
        ..writeln(
          '<text x="${sx(bounds.center.x)}" y="${sy(bounds.center.y) + 12}" '
          'font-size="9" text-anchor="middle" fill="#42535A">'
          '${bounds.width.toStringAsFixed(2)} × ${bounds.height.toStringAsFixed(2)} m · '
          '${bounds.area.toStringAsFixed(1)} m²</text>',
        );
    }
    buffer
      ..writeln(
        '<text x="$margin" y="20" font-size="12" fill="#42535A">'
        'Conceptual floor plan · Floor ${floorIndex + 1} · Seed ${candidate.seed}</text>',
      )
      ..writeln('</g></svg>');
    return buffer.toString();
  }

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
