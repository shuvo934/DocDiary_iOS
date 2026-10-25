import '../../auth/profile_repository.dart';
import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../../core/native_json.dart';

const scheduleMonths = [
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

class DoctorAppointmentWindow {
  DoctorAppointmentWindow(DateTime now)
    : anchor = dateOnly(now),
      first = dateOnly(calendarAddMonths(now, -1)),
      last = dateOnly(calendarAddMonths(now, 1));
  final DateTime anchor, first, last;
  bool contains(DateTime day) =>
      !dateOnly(day).isBefore(first) && !dateOnly(day).isAfter(last);
  int get length =>
      DateTime.utc(
        last.year,
        last.month,
        last.day,
      ).difference(DateTime.utc(first.year, first.month, first.day)).inDays +
      1;
  int indexOf(DateTime day) =>
      DateTime.utc(
        day.year,
        day.month,
        day.day,
      ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
  DateTime dayAt(int index) =>
      DateTime(first.year, first.month, first.day + index);
  bool canMove(DateTime day, int delta) {
    final month = DateTime(day.year, day.month + delta);
    return !month.isBefore(DateTime(first.year, first.month)) &&
        !month.isAfter(DateTime(last.year, last.month));
  }

  DateTime move(DateTime day, int delta) {
    if (!canMove(day, delta)) return day;
    final target = dateOnly(calendarAddMonths(day, delta));
    return target.isBefore(first)
        ? first
        : target.isAfter(last)
        ? last
        : target;
  }

  static String label(DateTime day) =>
      '${scheduleMonths[day.month - 1]}, ${day.year}';
}

class DoctorAppointmentFeatures {
  DoctorAppointmentFeatures(AccountProfile profile)
    : history = profile.value('pat_app_history') == '1',
      upcomingHistory = profile.value('upcoming_pat_history') == '1',
      needAvail = profile.value('is_need_avail') == '1',
      dynamicPrescription =
          profile.value('presc_active') == '1' &&
          profile.value('can_prescribe') == '1';
  final bool history, upcomingHistory, needAvail, dynamicPrescription;
}

enum DoctorAppointmentAction {
  avail,
  history,
  progress,
  legacyPrescription,
  dynamicPrescription,
  prescriptionPreview,
  walkIn,
  video,
}

enum DoctorAppointmentTone { empty, upcoming, completed, awaitingAvail, missed }

class DoctorAppointmentRow {
  DoctorAppointmentRow(JsonMap row, {required this.selectedDate})
    : values = Map.unmodifiable({
        for (final key in keys) key: _field(row, key),
      }) {
    if (booked && value('pph_progress') != '0') {
      final progress = num.tryParse(value('pph_progress'));
      if (progress == null || !progress.isFinite) {
        throw const AppFailure(
          'The server returned an invalid "pph_progress" number for appointments.',
          kind: FailureKind.invalidData,
        );
      }
    }
  }
  static const numericDefaults = {
    'ts_video_conf_flag',
    'pmm',
    'rvm',
    'is_ranked',
    'pph_progress',
    'avail_flag',
  };
  static const keys = [
    'adm_date',
    'schedule_time',
    'patient_data',
    'depts_id',
    'depts_name',
    'pat_name',
    'pat_gender',
    'pat_id',
    'pat_code',
    'pat_age_now',
    'pfn_fee_name',
    'doc_video_link',
    'ts_video_conf_flag',
    'pmm',
    'rvm',
    'rvm_id',
    'is_ranked',
    'pph_progress',
    'pfn_id',
    'ph_cat_id',
    'ad_id',
    'ad_prm_id',
    'ad_prd_id',
    'avail_flag',
  ];
  static String _field(JsonMap row, String key) {
    if (!row.containsKey(key) ||
        row[key] is Map ||
        row[key] is List ||
        row[key] is bool) {
      throw AppFailure(
        'The server returned an invalid "$key" field for appointments.',
        kind: FailureKind.invalidData,
      );
    }
    return nativeText(row[key], numericDefaults.contains(key) ? '0' : '');
  }

  final Map<String, String> values;
  final DateTime selectedDate;
  String value(String key) => values[key] ?? '';
  String get id => value('ad_id');
  bool get booked {
    final number = double.tryParse(value('patient_data'));
    return number != null && number.isFinite;
  }

  DateTime? get startsAt {
    try {
      return parseAppointmentTime(
        oracleDate(selectedDate),
        value('schedule_time'),
      );
    } on AppFailure {
      return null;
    }
  }

  double get progressFraction =>
      ((num.tryParse(value('pph_progress')) ?? 0) / 10)
          .clamp(0, 1)
          .toDouble(); // Native ProgressBar max is 10, not 100.
  DoctorAppointmentPresentation present(
    DoctorAppointmentFeatures flags,
    DateTime now,
  ) => DoctorAppointmentPresentation(this, flags, now);
}

/// A pure translation of TimeLineAdapter's status and visibility branches.
class DoctorAppointmentPresentation {
  DoctorAppointmentPresentation(this.row, this.features, this.now);
  final DoctorAppointmentRow row;
  final DoctorAppointmentFeatures features;
  final DateTime now;
  bool get booked => row.booked;
  bool get timed => row.startsAt != null;
  bool get past => timed && row.startsAt!.isBefore(now);
  bool get today => row.value('adm_date') == oracleDate(now);
  bool get hasProgress => row.value('pph_progress') != '0';
  bool get progressChecked => booked && row.value('is_ranked') != '0';
  DoctorAppointmentTone get tone {
    if (!booked) return DoctorAppointmentTone.empty;
    if (!timed || !past) return DoctorAppointmentTone.upcoming;
    if (!features.needAvail) return DoctorAppointmentTone.completed;
    // Native deliberately shows older requests as Not Availed, even if the
    // returned avail_flag is 1. Preserve that existing branch for this phase.
    if (!today) return DoctorAppointmentTone.missed;
    return row.value('avail_flag') == '1'
        ? DoctorAppointmentTone.completed
        : DoctorAppointmentTone.awaitingAvail;
  }

  String get patientLabel {
    if (booked) return row.value('pat_name');
    if (row.value('patient_data').isNotEmpty) return row.value('patient_data');
    return past ? 'No Meeting happened' : '...';
  }

  bool get showHistory =>
      booked &&
      timed &&
      features.history &&
      (past ? today : today || features.upcomingHistory);
  bool get showAvail =>
      booked &&
      timed &&
      past &&
      today &&
      features.needAvail &&
      row.value('avail_flag') != '1';
  String? get availMessage {
    if (!booked || !timed || !past || !features.needAvail) return null;
    if (!today) return 'Not Availed';
    return row.value('avail_flag') == '1' ? 'Availed' : null;
  }

  bool get showProgress => booked && ((timed && past && today) || hasProgress);
  String get progressLabel =>
      past && today && (!hasProgress || !progressChecked)
          ? 'ADD PROGRESS'
          : 'VIEW PROGRESS';
  bool get showPrescription =>
      booked &&
      timed &&
      (!features.dynamicPrescription || today || row.value('rvm') != '0');
  String get prescriptionLabel =>
      features.dynamicPrescription
          ? (row.value('rvm') != '0' ? 'Prescription' : 'Create Prescription')
          : (row.value('pmm') == '1' ? 'Prescription' : 'Create Prescription');
  DoctorAppointmentAction get prescriptionAction =>
      !features.dynamicPrescription
          ? DoctorAppointmentAction.legacyPrescription
          : today
          ? DoctorAppointmentAction.dynamicPrescription
          : DoctorAppointmentAction.prescriptionPreview;
  bool get videoEligible =>
      booked && timed && !past && row.value('ts_video_conf_flag') == '1';
  bool get showVideo =>
      videoEligible &&
      !now.isBefore(row.startsAt!.subtract(const Duration(minutes: 10)));
  bool get showVideoNotice => videoEligible && !showVideo;
  Set<DoctorAppointmentAction> get actions => {
    if (showAvail) DoctorAppointmentAction.avail,
    if (showHistory) DoctorAppointmentAction.history,
    if (showProgress) DoctorAppointmentAction.progress,
    if (showPrescription) prescriptionAction,
    if (showVideo) DoctorAppointmentAction.video,
  };
}
