import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../../core/native_json.dart';
import 'native_dashboard_format.dart';

enum AdminChartKind { payment, appointment }

enum AdminChartMode { monthly, yearly }

enum AdminChartType { all, offline, online }

const chartMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class AdminChartSelection {
  AdminChartSelection(this.mode, DateTime date)
    : first = DateTime(
        date.year,
        mode == AdminChartMode.monthly ? date.month : 1,
      );
  final AdminChartMode mode;
  final DateTime first;
  DateTime get last =>
      mode == AdminChartMode.monthly
          ? DateTime(first.year, first.month + 1, 0)
          : DateTime(first.year, 12, 31);
  String get label =>
      mode == AdminChartMode.monthly
          ? 'MONTH: ${chartMonths[first.month - 1].substring(0, 3).toUpperCase()}-'
              '${(first.year % 100).toString().padLeft(2, '0')}'
          : 'YEAR: ${first.year}';
  Map<String, String> get query => {
    'begin_date': oracleDate(first),
    'end_date': oracleDate(last),
  };

  bool isAllowed(DateTime now) {
    if (mode == AdminChartMode.yearly) {
      return first.year >= now.year - 10 && first.year <= now.year;
    }
    final current = now.year * 12 + now.month;
    final selected = first.year * 12 + first.month;
    return selected >= current - 11 && selected <= current;
  }
}

BigInt _ten(int exponent) => BigInt.from(10).pow(exponent);

/// Keep exact decimal totals; only plotted points use Android's float precision.
class AdminChartNumber {
  const AdminChartNumber._(this.units, this.scale, this.plot);
  final BigInt units;
  final int scale;
  final double plot;

  factory AdminChartNumber.parse(Object? value) {
    final text = nativeText(value, '0').trim();
    final match = RegExp(
      r'^([+-]?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$',
    ).firstMatch(text);
    if (match == null) {
      throw const AppFailure(
        'The server returned an invalid chart number.',
        kind: FailureKind.invalidData,
      );
    }
    final fraction = match[3] ?? '';
    final exponent = int.tryParse(match[4] ?? '0');
    if (exponent == null ||
        exponent.abs() > 128 ||
        fraction.length > 128 ||
        match[2]!.length > 128) {
      throw const AppFailure(
        'The server returned an invalid chart number.',
        kind: FailureKind.invalidData,
      );
    }
    var scale = fraction.length - exponent;
    var units = BigInt.parse('${match[1]}${match[2]}$fraction');
    if (scale < 0) {
      units *= _ten(-scale);
      scale = 0;
    }
    final doubleValue = double.tryParse(text);
    final plot =
        doubleValue == null
            ? double.nan
            : Float32List.fromList([doubleValue]).single;
    if (!plot.isFinite) {
      throw const AppFailure(
        'The server returned an invalid chart number.',
        kind: FailureKind.invalidData,
      );
    }
    return AdminChartNumber._(units, scale, plot);
  }

  bool get isWhole => units.remainder(_ten(scale)) == BigInt.zero;
}

String chartGroupInteger(String value) {
  final negative = value.startsWith('-');
  final digits = negative ? value.substring(1) : value;
  final result = StringBuffer(negative ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      result.write(',');
    }
    result.write(digits[i]);
  }
  return result.toString();
}

/// Android DecimalFormat's default whole-number rounding is HALF_EVEN.
String chartTotal(Iterable<AdminChartNumber> values, {bool currency = false}) {
  final numbers = values.toList(growable: false);
  final scale = numbers.fold<int>(
    0,
    (current, number) => math.max(current, number.scale),
  );
  final units = numbers.fold<BigInt>(
    BigInt.zero,
    (total, number) => total + number.units * _ten(scale - number.scale),
  );
  final divisor = _ten(scale);
  var rounded = units.abs() ~/ divisor;
  final remainder = units.abs().remainder(divisor) * BigInt.from(2);
  if (remainder > divisor || (remainder == divisor && rounded.isOdd)) {
    rounded += BigInt.one;
  }
  if (units.isNegative) {
    rounded = -rounded;
  }
  final integer = rounded.toString();
  // Payment totals use DecimalFormat's lakh/crore pattern. Native appointment
  // totals use String.valueOf(int); marker tooltips have their own grouping.
  return currency ? '৳ ${nativePaymentInteger(integer)}' : integer;
}

/// MPAndroidChart LargeValueFormatter: engineering groups, three significant
/// digits, k/m/b/t and a five-character cap. Tiny fractions are kept readable
/// instead of copying its negative-exponent/suffix failure.
String chartCompact(double number) {
  if (number == 0) {
    return '0';
  }
  if (number.abs() < 1) {
    return number
        .toStringAsPrecision(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  var group =
      (math.log(number.abs()) / math.log(1000)).floor().clamp(0, 4).toInt();
  var scaled = number / math.pow(1000, group);
  var digits =
      (3 - (math.log(scaled.abs()) / math.ln10).floor() - 1)
          .clamp(0, 3)
          .toInt();
  var text = scaled.toStringAsFixed(digits);
  if (double.parse(text).abs() >= 1000 && group < 4) {
    group++;
    scaled = number / math.pow(1000, group);
    digits = 2;
    text = scaled.toStringAsFixed(digits);
  }
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  text += const ['', 'k', 'm', 'b', 't'][group];
  while (group > 0 &&
      (text.length > 5 || RegExp(r'^\d+\.[a-z]$').hasMatch(text))) {
    text = text.substring(0, text.length - 2) + text.substring(text.length - 1);
  }
  return text;
}

class AdminChartPoint {
  const AdminChartPoint(this.label, this.primary, this.secondary);
  final String label;
  final AdminChartNumber primary;
  final AdminChartNumber secondary;
}

class AdminChartData {
  AdminChartData(this.kind, List<AdminChartPoint> points)
    : points = List.unmodifiable(points);
  final AdminChartKind kind;
  final List<AdminChartPoint> points;
  String get primaryTotal => chartTotal(
    points.map((point) => point.primary),
    currency: kind == AdminChartKind.payment,
  );
  String get secondaryTotal => chartTotal(
    points.map((point) => point.secondary),
    currency: kind == AdminChartKind.payment,
  );

  factory AdminChartData.fromResponse(
    AdminChartKind kind,
    AdminChartMode mode,
    JsonMap response,
  ) {
    if (nativeText(response['count']) == '0') {
      return AdminChartData(kind, const []);
    }
    if (!response.containsKey('items') || response['items'] == null) {
      throw const AppFailure(
        'The server returned an incomplete chart response.',
        kind: FailureKind.invalidData,
      );
    }
    final rows = nativeItems(response);
    final points = <AdminChartPoint>[];
    for (final row in rows) {
      final primary = AdminChartNumber.parse(
        row[kind == AdminChartKind.payment ? 'amount' : 'total_app'],
      );
      final secondary = AdminChartNumber.parse(
        row[kind == AdminChartKind.payment ? 'amount1' : 'cancel_app'],
      );
      if (kind == AdminChartKind.appointment &&
          (!primary.isWhole || !secondary.isWhole)) {
        throw const AppFailure(
          'The server returned an invalid appointment count.',
          kind: FailureKind.invalidData,
        );
      }
      points.add(
        AdminChartPoint(
          nativeText(row[mode == AdminChartMode.monthly ? 'dates' : 'pmonths']),
          primary,
          secondary,
        ),
      );
    }
    return AdminChartData(kind, points);
  }
}

class AdminChartPair {
  const AdminChartPair(this.payment, this.appointment);
  final AdminChartData payment;
  final AdminChartData appointment;
}
