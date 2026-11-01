import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../../core/native_json.dart';
import '../../auth/profile_repository.dart';
import '../../dashboard/dashboard_navigation.dart';
import '../../dashboard/native_dashboard_layout.dart';

bool adminAppointmentAllowed(AccountProfile profile) =>
    !profile.isDoctor &&
    nativeDashboardRoute(profile, DashboardDestination.appointment)?.module ==
        DashboardModule.adminAppointments;
bool adminAppointmentId(String value) =>
    RegExp(r'^[1-9][0-9]*$').hasMatch(value);
void adminAppointmentRequire(bool condition, String message) {
  if (!condition) throw AppFailure(message, kind: FailureKind.invalidData);
}

class AdminAppointmentUnavailable implements Exception {
  const AdminAppointmentUnavailable();
}

/// Identity is independent of the displayed name; one doctor may have several
/// unit/designation rows and patients may have multiple prescription records.
class AdminAppointmentChoice {
  AdminAppointmentChoice(
    JsonMap source,
    this.idField,
    this.nameField, {
    List<String> identity = const [],
  }) : data = Map.unmodifiable(source),
       identityFields = List.unmodifiable(identity) {
    adminAppointmentRequire(
      adminAppointmentId(id),
      'The server returned an invalid appointment identifier.',
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
  factory AdminAppointmentChoice.patient(JsonMap data) =>
      AdminAppointmentChoice(data, 'ph_id', 'pat_name');
  factory AdminAppointmentChoice.doctor(JsonMap data) => AdminAppointmentChoice(
    data,
    'doc_id',
    'doc_name',
    identity: ['depts_id', 'desig_id'],
  );
  factory AdminAppointmentChoice.payment(JsonMap data) =>
      AdminAppointmentChoice(data, 'prm_id', 'prm_code');
  factory AdminAppointmentChoice.service(JsonMap data) =>
      AdminAppointmentChoice(
        data,
        'pfn_id',
        'pfn_fee_name',
        identity: ['prd_id'],
      );
}

class AdminAppointmentDay {
  AdminAppointmentDay(JsonMap data)
    : id = nativeText(data['adm_id']),
      date = parseOracleDate(nativeText(data['p_adm_date'])) {
    adminAppointmentRequire(
      adminAppointmentId(id),
      'The server returned an invalid appointment date identifier.',
    );
  }
  AdminAppointmentDay.selected(this.id, this.date);
  final String id;
  final DateTime date;
  String get label => oracleDate(date);
}

class AdminAppointmentTime {
  AdminAppointmentTime(JsonMap data)
    : id = nativeText(data['ts_id']),
      label = nativeText(data['schedule']) {
    adminAppointmentRequire(
      adminAppointmentId(id) && label.isNotEmpty,
      'The server returned an invalid appointment time.',
    );
  }
  final String id, label;
}

class AdminCancellation {
  AdminCancellation(JsonMap data)
    : id = nativeText(data['ad_id']),
      date = nativeText(data['app_date']),
      times = List.unmodifiable(
        nativeArray(
          data['time_list'],
        ).map((row) => nativeText(row['schedule'])),
      ) {
    adminAppointmentRequire(
      adminAppointmentId(id),
      'The server returned an invalid appointment identifier.',
    );
    parseOracleDate(date);
    for (final time in times) {
      parseAppointmentTime(date, time);
    }
  }
  final String id, date;
  final List<String> times;
  bool canCancel(DateTime now, {required bool fullAccess}) {
    final cutoff =
        fullAccess
            ? now
            : DateTime(
              now.year,
              now.month,
              now.day + 1,
              now.hour,
              now.minute,
              now.second,
              now.millisecond,
              now.microsecond,
            );
    return times.isNotEmpty &&
        times.every(
          (time) => !parseAppointmentTime(date, time).isBefore(cutoff),
        );
  }
}

class AdminScheduleLimit {
  AdminScheduleLimit(JsonMap data)
    : allowed = _quantity(data, 'allowed_qty'),
      taken = _quantity(data, 'taken_service_qty');
  final int allowed, taken;
  bool permits(int count) => allowed == 0 || taken + count < allowed;
}

int _quantity(JsonMap data, String key) {
  adminAppointmentRequire(
    data.containsKey(key),
    'The server returned incomplete service quantity data.',
  );
  final value = int.tryParse(nativeText(data[key], '0'));
  adminAppointmentRequire(
    value != null && value >= 0,
    'The server returned invalid service quantity data.',
  );
  return value!;
}

class AdminSchedule {
  AdminSchedule({
    required this.day,
    required this.time,
    required this.taken,
    this.submitted = false,
    this.duplicate = false,
  });
  final AdminAppointmentDay day;
  final AdminAppointmentTime time;
  final bool taken;
  bool submitted, duplicate;
  bool get locked => submitted && !duplicate;
}

/// Draft is owned by AppointmentModify, not by its dialogs or schedule page.
class AdminAppointmentDraft {
  AdminAppointmentDraft({this.cancel = false});
  final bool cancel;
  AdminAppointmentChoice? patient, doctor, payment, service;
  AdminCancellation? cancellation;
  AdminScheduleLimit? limit;
  final schedules = <AdminSchedule>[];
  List<AdminAppointmentChoice> doctors = const [],
      payments = const [],
      services = const [];
  List<AdminCancellation> cancellations = const [];
  bool get collisions => schedules.any((row) => row.submitted && row.duplicate);
  bool get stored => cancel ? cancellation != null : schedules.isNotEmpty;
  int get remaining {
    if (service == null || cancel) return 0;
    final used =
        schedules
            .where((row) => !row.taken)
            .map((row) => row.day.id)
            .toSet()
            .length;
    return _quantity(service!.data, 'rest') - used;
  }

  void selectPatient(AdminAppointmentChoice value) {
    patient = value;
    doctors = const [];
    selectDoctor(null);
  }

  void selectDoctor(AdminAppointmentChoice? value) {
    doctor = value;
    payments = const [];
    selectPayment(null);
  }

  void selectPayment(AdminAppointmentChoice? value) {
    payment = value;
    services = const [];
    selectService(null);
  }

  void selectService(AdminAppointmentChoice? value) {
    service = value;
    cancellation = null;
    cancellations = const [];
    limit = null;
    schedules.clear();
  }

  String? get missing {
    if (patient == null) return 'Please Select Patient';
    if (doctor == null) return 'Please Select Doctor';
    if (!cancel && payment == null) return 'Please Select Payment Code';
    if (service == null) return 'Please Select Service';
    if (cancel && cancellation == null) return 'Please Select Appointment Date';
    if (cancel && cancellation!.times.isEmpty) {
      return 'No Time Schedule Found for this Date.';
    }
    if (!cancel && schedules.isEmpty) {
      return 'Please Select Appointment Time to Save.';
    }
    return null;
  }

  void add(AdminSchedule row, {int? replacing}) {
    adminAppointmentRequire(service != null, 'Please Select Service');
    adminAppointmentRequire(
      !schedules.asMap().entries.any(
        (e) =>
            e.key != replacing &&
            e.value.day.id == row.day.id &&
            e.value.time.id == row.time.id,
      ),
      'This appointment time is already selected.',
    );
    if (replacing == null) {
      final sameDay = schedules.any((r) => r.day.id == row.day.id);
      adminAppointmentRequire(
        sameDay || row.taken || remaining > 0,
        'Service Quantity is Empty',
      );
      adminAppointmentRequire(
        limit != null && limit!.permits(schedules.length),
        'Appointment Schedule limit reached.',
      );
      schedules.add(row);
    } else {
      adminAppointmentRequire(
        replacing >= 0 &&
            replacing < schedules.length &&
            !schedules[replacing].locked &&
            schedules[replacing].day.id == row.day.id,
        'This schedule cannot be changed.',
      );
      schedules[replacing] = row;
    }
  }

  void remove(int index) {
    adminAppointmentRequire(
      index >= 0 && index < schedules.length && !schedules[index].locked,
      'This schedule cannot be removed.',
    );
    schedules.removeAt(index);
  }
}

String? adminPatientSearchError(String value) {
  if (value.isEmpty) return 'Please Provide Patient Name or Code';
  if (value.length < 3) return 'Name or Code must be greater than 2 character';
  if (value.contains(RegExp(r'[.,-]'))) {
    return "Name or Code must not contain '.,-' character";
  }
  return null;
}

String adminPatientPhone(String value) {
  if (value.length <= 6) return value;
  return '${value.substring(0, 3)}${value.substring(3, value.length - 3).replaceAll(RegExp(r'[0-9]'), '*')}${value.substring(value.length - 3)}';
}
