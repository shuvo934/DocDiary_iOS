import '../../core/native_json.dart';
import '../../core/native_dates.dart';
import 'payment_models.dart';

const paymentScheduleWarning =
    'Appointment Schedule already taken from this payment. You will not be able to update this payment.';

class PaymentUpdateUnavailable extends PaymentUnavailable {
  const PaymentUpdateUnavailable();
}

class PaymentRecordChanged implements Exception {
  const PaymentRecordChanged();
}

class PaymentScheduleBlocked implements Exception {
  const PaymentScheduleBlocked(this.lines);
  final List<PaymentUpdateLine> lines;
}

String? paymentCodeSearchError(String value) {
  if (value.isEmpty) return 'Please Provide Payment Code';
  if (value.startsWith('.')) return "Code must not start with '.' character";
  if (value.length < 5) return 'Code must be greater than 4 character';
  if (value.toUpperCase().contains('PR.')) return "Code must not include 'PR'";
  return null;
}

PaymentChoice paymentRecord(JsonMap row) {
  final choice = PaymentChoice(row, 'prm_id', 'prm_code');
  PaymentChoice.patient(row);
  parseOracleDate(choice.value('prm_date'));
  return choice;
}

int _count(Object? value, {bool positive = false}) {
  final text = nativeText(value, '0'), number = int.tryParse(text);
  paymentRequire(
    RegExp(r'^\d+$').hasMatch(text) &&
        number != null &&
        number >= (positive ? 1 : 0) &&
        number <= 2147483647,
    'The server returned an invalid service quantity.',
  );
  return number!;
}

class PaymentUpdateLine {
  PaymentUpdateLine({
    required this.line,
    this.id = '',
    required this.available,
    this.schedule = 0,
    this.cancel = 0,
    this.returned = 0,
    this.changed = false,
  }) {
    paymentRequire(
      (id.isEmpty || paymentId(id)) &&
          available >= 0 &&
          available <= line.quantity &&
          schedule >= 0 &&
          cancel >= 0 &&
          returned >= 0,
      'The server returned invalid service availability.',
    );
  }
  factory PaymentUpdateLine.fromJson(JsonMap row) {
    final id = nativeText(row['prd_id']);
    paymentRequire(
      paymentId(id) && row.containsKey('available_qty'),
      'The server returned incomplete payment service details.',
    );
    final rate = PaymentRate.fromJson({
      'p_service_rate': row['prd_rate'],
      'p_service_top_rate': row['prd_top_cat_rate'],
    });
    paymentRequire(
      row.containsKey('prd_rate') && row.containsKey('prd_top_cat_rate'),
      'The server returned an incomplete service rate.',
    );
    final line = PaymentServiceLine(
      service: PaymentChoice.service({
        'pfn_id': row['prd_pfn_id'],
        'pfn_fee_name': row['pfn_fee_name'],
      }),
      unit: PaymentChoice.unit({
        'depts_id': row['prd_depts_id'],
        'depts_name': row['depts_name'],
      }),
      rate: rate,
      quantity: _count(row['prd_qty'], positive: true),
    );
    paymentRequire(
      paymentCents(nativeText(row['amount'])) == line.amount,
      'The server returned an inconsistent service amount.',
    );
    return PaymentUpdateLine(
      line: line,
      id: id,
      available: _count(row['available_qty']),
      schedule: _count(row['prd_sched_avail_mark']),
      cancel: _count(row['prd_cancel_mark']),
      returned: _count(row['prd_return_mark']),
    );
  }
  final String id;
  final PaymentServiceLine line;
  final int available, schedule, cancel, returned;
  final bool changed;
  int get used => line.quantity - available;
  bool get canChangeUnit => used == 0;
  String get key => id.isEmpty ? 'new:${line.key}' : id;
  String get fingerprint => [
    id,
    line.key,
    line.quantity,
    line.rate.cents,
    line.rate.topCents,
    available,
    schedule,
    cancel,
    returned,
  ].join('|');
  PaymentUpdateLine edited(PaymentServiceLine next) {
    paymentRequire(
      next.service.id == line.service.id,
      'This service cannot be changed.',
    );
    paymentRequire(
      canChangeUnit || next.unit.id == line.unit.id,
      'This unit cannot be changed.',
    );
    paymentRequire(
      next.quantity >= used,
      'You can not provide quantity less than $used.',
    );
    return PaymentUpdateLine(
      line: next,
      id: id,
      available: next.quantity - used,
      schedule: schedule,
      cancel: cancel,
      returned: returned,
      changed: true,
    );
  }
}

PaymentAllocation savedPaymentAllocation(JsonMap row) {
  final id = nativeText(row['prmd_id']),
      cents = paymentCents(nativeText(row['prmd_amt']));
  paymentRequire(
    paymentId(id) && cents != null,
    'The server returned invalid saved payment methods.',
  );
  return PaymentAllocation(
    PaymentChoice.method({
      'pmm_id': row['prmd_pmm_id'],
      'pmm_name': row['pmm_name'],
      'pmd_id': row['prmd_pmd_id'],
      'ad_id': row['prmd_ad_id'],
      'account_name': row['account_name'],
    }),
    cents!,
    savedId: id,
  );
}

class PaymentUpdateDraft {
  PaymentChoice? payment;
  List<PaymentUpdateLine> lines = [], originals = [];
  List<PaymentAllocation> methods = [];
  bool loaded = false, scheduleBlocked = false;
  PaymentUpdateSubmission? submission;
  PaymentChoice? get patient =>
      payment == null ? null : PaymentChoice.patient(payment!.data);
  bool get locked => submission != null;
  bool get blocked => scheduleBlocked || lines.any((r) => r.schedule > 0);
  int get total => lines.fold(0, (n, r) => n + r.line.amount);
  void select(PaymentChoice value) {
    paymentRequire(!locked, 'This payment is already being processed.');
    payment = value;
    lines = [];
    originals = [];
    methods = [];
    loaded = false;
    scheduleBlocked = false;
  }

  void load(List<PaymentUpdateLine> next, List<PaymentAllocation> saved) {
    lines = List.of(next);
    originals = List.unmodifiable(next);
    methods = List.unmodifiable(saved);
    loaded = true;
    scheduleBlocked = next.any((r) => r.schedule > 0);
  }

  void add(PaymentServiceLine line, {PaymentUpdateLine? replacing}) {
    paymentRequire(!locked && !blocked && loaded, paymentScheduleWarning);
    paymentRequire(
      !lines.any((r) => !identical(r, replacing) && r.line.key == line.key),
      'This Service is already added. Recheck again.',
    );
    paymentRequire(
      BigInt.from(total - (replacing?.line.amount ?? 0)) +
              BigInt.from(line.amount) <=
          BigInt.from(paymentMaxCents),
      'The payment amount is too large. Please check the services.',
    );
    if (replacing == null) {
      lines.add(
        PaymentUpdateLine(line: line, available: line.quantity, changed: true),
      );
    } else {
      final index = lines.indexOf(replacing);
      paymentRequire(index >= 0, 'Please reopen the service.');
      lines[index] = replacing.edited(line);
    }
  }
}

class PaymentMethodChange {
  const PaymentMethodChange(this.type, this.allocation);
  final String type;
  final PaymentAllocation allocation;
}

class PaymentUpdateSubmission {
  PaymentUpdateSubmission(PaymentUpdateDraft draft, this.confirmation)
    : payment = draft.payment!,
      originals = List.unmodifiable(draft.originals),
      originalMethods = List.unmodifiable(draft.methods),
      lines = List.unmodifiable(draft.lines),
      serviceChanges = List.unmodifiable(draft.lines.where((r) => r.changed)) {
    paymentRequire(
      draft.loaded && draft.lines.isNotEmpty && !draft.blocked,
      paymentScheduleWarning,
    );
    if (confirmation != null) {
      paymentRequire(
        confirmation!.quote.total == total,
        'The services changed. Please reopen payment confirmation.',
      );
      PaymentConfirmation(
        confirmation!.quote,
        confirmation!.allocations,
        saved: originalMethods,
      );
      final kept =
          confirmation!.allocations
              .where((a) => a.savedId.isNotEmpty)
              .map((a) => a.savedId)
              .toSet();
      methodChanges = List.unmodifiable([
        for (final old in originalMethods)
          if (!kept.contains(old.savedId)) PaymentMethodChange('2', old),
        for (final added in confirmation!.allocations)
          if (added.savedId.isEmpty) PaymentMethodChange('1', added),
      ]);
    } else {
      methodChanges = const [];
    }
  }
  final PaymentChoice payment;
  final List<PaymentUpdateLine> lines, originals, serviceChanges;
  final List<PaymentAllocation> originalMethods;
  final PaymentConfirmation? confirmation;
  late final List<PaymentMethodChange> methodChanges;
  int servicesAcknowledged = 0, methodsAcknowledged = 0;
  bool started = false, uncertain = false;
  int get total => lines.fold(0, (n, r) => n + r.line.amount);
  bool get hasChanges => serviceChanges.isNotEmpty || methodChanges.isNotEmpty;
  bool get complete =>
      hasChanges &&
      !uncertain &&
      servicesAcknowledged == serviceChanges.length &&
      methodsAcknowledged == methodChanges.length;
}
