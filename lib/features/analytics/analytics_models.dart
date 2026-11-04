import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../../core/native_json.dart';

enum AnalyticsSection { mobile, portal, appointments, payments }

class AnalyticsRange {
  AnalyticsRange(DateTime first, DateTime last)
    : first = dateOnly(first),
      last = dateOnly(last);

  factory AnalyticsRange.today(DateTime now) => AnalyticsRange(now, now);

  final DateTime first, last;

  bool allowed(DateTime now) =>
      !first.isBefore(DateTime(1900)) &&
      !first.isAfter(last) &&
      !last.isAfter(dateOnly(now));

  Map<String, String> get query => {
    'begin_date': _analyticsDate(first),
    'end_date': _analyticsDate(last),
  };
}

// The native request formatter is dd-MMM-yy with an English month name.
String _analyticsDate(DateTime date) {
  final value = oracleDate(date);
  return '${value.substring(0, 4)}${value.substring(4, 6).toLowerCase()}${value.substring(6)}';
}

int analyticsCount(JsonMap row, String key) {
  final value = row[key];
  final text = nativeText(value, '0').trim();
  final count =
      row.containsKey(key) && (value == null || value is String || value is num)
          ? int.tryParse(text)
          : null;
  if (count == null || count < 0) {
    throw const AppFailure(
      'The server returned an invalid analytics count.',
      kind: FailureKind.invalidData,
    );
  }
  return count;
}

String analyticsLabel(JsonMap row, String key, {String fallback = ''}) {
  final value = row[key];
  if (!row.containsKey(key) || (value != null && value is! String)) {
    throw const AppFailure(
      'The server returned an invalid analytics label.',
      kind: FailureKind.invalidData,
    );
  }
  return nativeText(value, fallback);
}

class AnalyticsPoint {
  const AnalyticsPoint(this.label, this.values);

  final String label;
  final List<int> values;
}

class AnalyticsTrend {
  AnalyticsTrend(List<JsonMap> rows, List<String> fields)
    : points = List.unmodifiable([
        for (final row in rows)
          AnalyticsPoint(
            analyticsLabel(row, 'all_dates').toUpperCase(),
            List.unmodifiable([
              for (final field in fields) analyticsCount(row, field),
            ]),
          ),
      ]),
      seriesCount = fields.length;

  final List<AnalyticsPoint> points;
  final int seriesCount;

  int total(int series) =>
      points.fold(0, (total, point) => total + point.values[series]);

  // MPAndroidChart uses two zero endpoints around a single real point.
  List<AnalyticsPoint> get plotPoints {
    if (points.length != 1) return points;
    final zero = AnalyticsPoint('', List.filled(seriesCount, 0));
    return [zero, points.single, zero];
  }
}

class AnalyticsLogin {
  const AnalyticsLogin(this.trend, this.unique);
  final AnalyticsTrend trend;
  final int unique;
}

class AnalyticsAppointments {
  const AnalyticsAppointments(this.initialized, this.scheduled);
  final AnalyticsTrend initialized, scheduled;
}

enum AnalyticsCardStatus {
  completed('Completed'),
  failed('Failed'),
  noResult('No Result');

  const AnalyticsCardStatus(this.label);
  final String label;
}

const analyticsPaymentFields = [
  'all_pay_count',
  'c_pay_count',
  'f_pay_count',
  'na_pay_count',
];

class AnalyticsCard {
  AnalyticsCard(JsonMap row)
    : name = analyticsLabel(row, 'card_name'),
      values = List.unmodifiable([
        for (final field in analyticsPaymentFields) analyticsCount(row, field),
      ]);

  final String name;
  final List<int> values;

  int get total => values.first;
  int count(AnalyticsCardStatus status) => values[status.index + 1];
  int percentage(AnalyticsCardStatus status) =>
      total == 0 ? 0 : (count(status) * 100 / total).round();
}

class AnalyticsPayments {
  AnalyticsPayments(this.trend, List<JsonMap> cards)
    : cards = List.unmodifiable(cards.map(AnalyticsCard.new));
  final AnalyticsTrend trend;
  final List<AnalyticsCard> cards;
}

class AnalyticsReason {
  AnalyticsReason(JsonMap row)
    : type = analyticsLabel(row, 'result_type', fallback: 'Not Available'),
      description = analyticsLabel(
        row,
        'result_desc',
        fallback: 'Not Available',
      ),
      count = analyticsCount(row, 'failed_count');

  final String type, description;
  final int count;
}

typedef AnalyticsCardSelection =
    ({AnalyticsCard card, AnalyticsCardStatus status});
