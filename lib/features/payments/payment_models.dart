import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/native_dates.dart';
import '../auth/profile_repository.dart';
import '../dashboard/dashboard_navigation.dart';
import '../dashboard/native_dashboard_layout.dart';

bool paymentAllowed(AccountProfile profile) =>
    !profile.isDoctor &&
    nativeDashboardRoute(profile, DashboardDestination.payment)?.module ==
        DashboardModule.adminPayments;

class PaymentUnavailable implements Exception {
  const PaymentUnavailable();
}

void paymentRequire(bool condition, String message) {
  if (!condition) throw AppFailure(message, kind: FailureKind.invalidData);
}

bool paymentId(String value) => RegExp(r'^[1-9][0-9]*$').hasMatch(value);
const paymentMaxCents = 9007199254740991;

String paymentDate(DateTime value) => oracleDate(value).replaceAllMapped(
  RegExp(r'-([A-Z]{3})-'),
  (m) => '-${m[1]![0]}${m[1]!.substring(1).toLowerCase()}-',
);

/// Store currency in hundredths. Neither totals nor split payments use double
/// equality, so (for example) 0.10 + 0.20 can cover a 0.30 payment exactly.
int? paymentCents(String text) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
  if (match == null) return null;
  final value =
      BigInt.parse(match[1]!) * BigInt.from(100) +
      BigInt.parse((match[2] ?? '').padRight(2, '0'));
  return value <= BigInt.from(paymentMaxCents) ? value.toInt() : null;
}

String paymentMoney(int cents, {bool fixed = false}) =>
    !fixed && cents % 100 == 0
        ? '${cents ~/ 100}'
        : '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

String? paymentQuantityError(String value) {
  if (value.isEmpty) return 'Please Provide Quantity';
  final n = int.tryParse(value);
  return RegExp(r'^[1-9][0-9]*$').hasMatch(value) &&
          n != null &&
          n <= 2147483647
      ? null
      : 'Invalid Quantity';
}

String? paymentSearchError(String value) {
  if (value.isEmpty) return 'Please Provide Patient Name or Code';
  if (value.length < 3) return 'Name or Code must be greater than 2 character';
  if (RegExp(r'[.,-]').hasMatch(value)) {
    return "Name or Code must not contain '.,-' character";
  }
  return null;
}

class PaymentChoice {
  PaymentChoice(
    JsonMap source,
    this.idField,
    this.nameField, {
    List<String> identity = const [],
  }) : data = Map.unmodifiable(source),
       identityFields = List.unmodifiable(identity) {
    paymentRequire(
      paymentId(id),
      'The server returned an invalid payment identifier.',
    );
    paymentRequire(
      name.isNotEmpty,
      'The server returned an incomplete payment choice.',
    );
  }
  final JsonMap data;
  final String idField, nameField;
  final List<String> identityFields;
  String value(String field) => nativeText(data[field]);
  String get id => value(idField);
  String get name => value(nameField);
  String get key =>
      [id, for (final field in identityFields) value(field)].join('|');
  factory PaymentChoice.patient(JsonMap row) {
    final choice = PaymentChoice(row, 'ph_id', 'pat_name');
    paymentRequire(
      paymentId(choice.value('ph_patient_cat_id')) &&
          choice.value('ph_sub_code').isNotEmpty,
      'The server returned incomplete patient payment details.',
    );
    return choice;
  }
  factory PaymentChoice.service(JsonMap row) =>
      PaymentChoice(row, 'pfn_id', 'pfn_fee_name');
  factory PaymentChoice.unit(JsonMap row) =>
      PaymentChoice(row, 'depts_id', 'depts_name');
  factory PaymentChoice.method(JsonMap row) {
    final choice = PaymentChoice(
      row,
      'pmm_id',
      'pmm_name',
      identity: ['pmd_id', 'ad_id'],
    );
    paymentRequire(
      paymentId(choice.value('pmd_id')) && paymentId(choice.value('ad_id')),
      'The server returned incomplete payment method details.',
    );
    return choice;
  }
}

class PaymentRate {
  const PaymentRate(this.cents, this.topCents);
  final int cents, topCents;
  factory PaymentRate.fromJson(JsonMap row) {
    paymentRequire(
      row.containsKey('p_service_rate') &&
          row.containsKey('p_service_top_rate'),
      'Invalid Rate. Select Unit Again',
    );
    final rate = paymentCents(nativeText(row['p_service_rate'], '0')),
        top = paymentCents(nativeText(row['p_service_top_rate'], '0'));
    paymentRequire(
      rate != null && top != null,
      'Invalid Rate. Select Unit Again',
    );
    return PaymentRate(rate!, top!);
  }
}

class PaymentServiceLine {
  PaymentServiceLine({
    required this.service,
    required this.unit,
    required this.rate,
    required this.quantity,
  }) {
    paymentRequire(
      paymentId(service.id) &&
          paymentId(unit.id) &&
          paymentQuantityError('$quantity') == null &&
          rate.cents >= 0 &&
          rate.topCents >= 0 &&
          rate.cents <= paymentMaxCents &&
          rate.topCents <= paymentMaxCents &&
          BigInt.from(rate.cents) * BigInt.from(quantity) <=
              BigInt.from(paymentMaxCents),
      'Invalid Quantity',
    );
  }
  final PaymentChoice service, unit;
  final PaymentRate rate;
  final int quantity;
  String get key => '${service.id}|${unit.id}';
  int get amount => rate.cents * quantity;
}

class PaymentAllocation {
  PaymentAllocation(this.method, this.cents) {
    paymentRequire(
      cents > 0 && cents <= paymentMaxCents,
      'Please Provide Amount',
    );
  }
  final PaymentChoice method;
  final int cents;
}

class PaymentQuote {
  PaymentQuote({
    required this.total,
    required this.charge,
    required List<PaymentChoice> methods,
  }) : methods = List.unmodifiable(methods) {
    paymentRequire(
      total >= 0 && charge >= 0 && total <= paymentMaxCents - charge,
      'The payment amount is too large. Please check the services.',
    );
  }
  final int total, charge;
  final List<PaymentChoice> methods;
  int get grandTotal => total + charge;
}

class PaymentConfirmation {
  PaymentConfirmation(this.quote, List<PaymentAllocation> allocations)
    : allocations = List.unmodifiable(allocations) {
    final keys = allocations.map((row) => row.method.key).toSet();
    paymentRequire(
      keys.length == allocations.length &&
          allocations.every(
            (a) => quote.methods.any((m) => m.key == a.method.key),
          ) &&
          allocations.fold<int>(0, (n, a) => n + a.cents) == quote.grandTotal,
      'Please provide full payment information',
    );
  }
  final PaymentQuote quote;
  final List<PaymentAllocation> allocations;
}

class PaymentDraft {
  PaymentChoice? patient;
  String date = '';
  final services = <PaymentServiceLine>[];
  PaymentSubmission? submission;
  int get total => services.fold(0, (n, line) => n + line.amount);
  bool get locked => submission != null;
  void selectPatient(PaymentChoice next, String today) {
    paymentRequire(!locked, 'This payment is already being processed.');
    patient = next;
    date = today;
    services.clear();
  }

  void add(PaymentServiceLine line, {PaymentServiceLine? replacing}) {
    paymentRequire(!locked, 'This payment is already being processed.');
    paymentRequire(
      !services.any((r) => !identical(r, replacing) && r.key == line.key),
      'This Service is already added. Recheck again.',
    );
    paymentRequire(
      BigInt.from(total - (replacing?.amount ?? 0)) +
              BigInt.from(line.amount) <=
          BigInt.from(paymentMaxCents),
      'The payment amount is too large. Please check the services.',
    );
    if (replacing == null) {
      services.add(line);
    } else {
      final index = services.indexOf(replacing);
      paymentRequire(index >= 0, 'Please reopen the service.');
      services[index] = line;
    }
  }
}

/// Immutable write plan plus acknowledged receipts. A partial retry starts at
/// the first rejected row, never by creating a second master payment.
class PaymentSubmission {
  PaymentSubmission(PaymentDraft draft, this.confirmation)
    : patient = draft.patient!,
      date = draft.date,
      lines = List.unmodifiable(draft.services) {
    paymentRequire(lines.isNotEmpty && date.isNotEmpty, 'Please Add Service.');
    paymentRequire(
      confirmation == null || confirmation!.quote.total == total,
      'The services changed. Please reopen payment confirmation.',
    );
    paymentRequire(
      lines.map((l) => l.key).toSet().length == lines.length,
      'This Service is already added. Recheck again.',
    );
  }
  final PaymentChoice patient;
  final String date;
  final List<PaymentServiceLine> lines;
  final PaymentConfirmation? confirmation;
  String? masterId, masterCode;
  int servicesAcknowledged = 0, methodsAcknowledged = 0;
  bool uncertain = false;
  int get total => lines.fold(0, (n, line) => n + line.amount);
  int get paid => confirmation?.quote.grandTotal ?? total;
  bool get complete =>
      masterId != null &&
      servicesAcknowledged == lines.length &&
      methodsAcknowledged == (confirmation?.allocations.length ?? 0) &&
      !uncertain;
}

class PaymentWriteUncertain implements Exception {
  const PaymentWriteUncertain();
}

class PaymentSettingsChanged implements Exception {
  const PaymentSettingsChanged();
}
