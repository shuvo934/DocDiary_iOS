import 'dart:math' as math;
import '../../core/failure.dart';
import '../../core/native_json.dart';

/// PrescriptionPdfGenerator.createPageSegments/findSafePageEnd. Coordinates
/// come only from the off-screen copy; the visible native HTML stays unchanged.
class DynamicPreviewPdfLayout {
  DynamicPreviewPdfLayout.fromData(JsonMap data) {
    double number(Object? value) {
      if (value is! num || !value.isFinite || value < 0) {
        throw const AppFailure('Prescription page layout is invalid.');
      }
      return value.toDouble();
    }

    contentTop = number(data['contentTop']).round();
    contentBottom = number(data['contentBottom']).round();
    footerTop = number(data['footerTop']).round();
    footerBottom = number(data['footerBottom']).round();
    documentHeight = number(data['documentHeight']).ceil();
    if (contentTop <= 0 ||
        contentBottom <= contentTop ||
        footerTop < contentBottom ||
        footerBottom <= footerTop ||
        documentHeight < footerBottom ||
        documentHeight > 600000) {
      throw const AppFailure('Prescription page layout is invalid.');
    }
    final source = data['ranges'];
    if (source is! List) {
      throw const AppFailure('Prescription page information was not returned.');
    }
    ranges = [
      for (final row in _rows(source))
        (
          top: math.max(contentTop, number(row['top']).round()),
          bottom: math.min(contentBottom, number(row['bottom']).round()),
        ),
    ];
    final columnsData = data['columns'];
    columns =
        columnsData is List
            ? [
              for (final row in _rows(columnsData))
                (
                  left: number(row['left']),
                  right: number(row['right']),
                  top: number(row['top']).round(),
                  bottom: number(row['bottom']).round(),
                  ranges: [
                    for (final range in _rows(row['ranges']))
                      (
                        top: number(range['top']).round(),
                        bottom: number(range['bottom']).round(),
                      ),
                  ],
                ),
            ]
            : [];
    for (final column in columns) {
      if (column.left >= column.right ||
          column.right > sourceWidth ||
          column.top < contentTop ||
          column.bottom > contentBottom ||
          column.bottom < column.top) {
        throw const AppFailure('Prescription column layout is invalid.');
      }
    }
  }
  // StandardMessageCodec uses Map<Object?,Object?> for nested maps, while
  // HTTP JSON uses Map<String,Object?>. Normalize both at this boundary.
  static List<JsonMap> _rows(Object? value) {
    if (value is! List) {
      throw const AppFailure('Prescription page information was not returned.');
    }
    try {
      return [
        for (final row in value)
          if (row is Map<Object?, Object?>) Map<String, Object?>.from(row),
      ];
    } catch (_) {
      throw const AppFailure('Prescription page layout is invalid.');
    }
  }

  static const sourceWidth = 794;
  static const pageWidth = 595, pageHeight = 842;
  late final int contentTop,
      contentBottom,
      footerTop,
      footerBottom,
      documentHeight;
  late final List<({int top, int bottom})> ranges;
  late final List<
    ({
      double left,
      double right,
      int top,
      int bottom,
      List<({int top, int bottom})> ranges,
    })
  >
  columns;
  int get availableHeight =>
      (pageHeight * sourceWidth / pageWidth -
              contentTop -
              (footerBottom - footerTop))
          .floor();
  List<({int start, int end})> segments() =>
      _segments(contentTop, contentBottom, ranges);

  List<({int start, int end})> _segments(
    int contentTop,
    int contentBottom,
    List<({int top, int bottom})> ranges, {
    int? firstCapacity,
  }) {
    final available = availableHeight;
    if (available <= 0) {
      throw const AppFailure(
        'Prescription header or footer is too large for an A4 page.',
      );
    }
    final pages = <({int start, int end})>[];
    var start = contentTop;
    while (start < contentBottom) {
      if (pages.length >= 500) {
        throw const AppFailure('Prescription contains too many pages.');
      }
      final capacity = pages.isEmpty ? firstCapacity ?? available : available;
      if (capacity <= 0) {
        throw const AppFailure(
          'Prescription patient summary is too large for an A4 page.',
        );
      }
      final proposed = math.min(start + capacity, contentBottom);
      var end = proposed;
      if (proposed < contentBottom) {
        bool changed;
        do {
          changed = false;
          for (final range in ranges) {
            final height = range.bottom - range.top;
            if (height <= 0 || height > capacity) continue;
            if (range.top > start && range.top < end && range.bottom > end) {
              end = range.top;
              changed = true;
            }
          }
        } while (changed);
      }
      if (end <= start) end = proposed;
      pages.add((start: start, end: end));
      start = end;
    }
    return List.unmodifiable(pages);
  }

  JsonMap toPlatform() => {
    'contentTop': contentTop,
    'contentBottom': contentBottom,
    'footerTop': footerTop,
    'footerBottom': footerBottom,
    'documentHeight': documentHeight,
    'pages': [
      if (columns.isEmpty)
        for (final page in segments()) {'start': page.start, 'end': page.end},
    ],
    if (columns.isNotEmpty) 'columnPages': _columnPages(),
  };

  /// Apply the native keep-together rule independently to parallel columns.
  /// Cross-column overlapping ranges have no common safe cut; treating them as
  /// one stream can otherwise produce dozens of nearly empty pages.
  List<List<JsonMap>> _columnPages() {
    final columnTop = columns.map((c) => c.top).reduce(math.min);
    final prefixHeight = columnTop - contentTop;
    final firstCapacity = availableHeight - prefixHeight;
    final tracks = [
      for (final column in columns)
        _segments(
          column.top,
          column.bottom,
          column.ranges,
          firstCapacity: firstCapacity,
        ),
    ];
    final count = tracks.map((track) => track.length).reduce(math.max);
    return [
      for (var index = 0; index < count; index++)
        [
          if (index == 0 && prefixHeight > 0)
            {
              'left': 0.0,
              'right': sourceWidth.toDouble(),
              'start': contentTop,
              'end': columnTop,
              'destination': contentTop,
            },
          for (var column = 0; column < columns.length; column++)
            if (index < tracks[column].length)
              {
                'left': columns[column].left,
                'right': columns[column].right,
                'start': tracks[column][index].start,
                'end': tracks[column][index].end,
                'destination': contentTop + (index == 0 ? prefixHeight : 0),
              },
        ],
    ];
  }
}
