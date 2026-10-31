import '../../../core/failure.dart';
import '../../../core/native_json.dart';
import '../../auth/profile_repository.dart';
import '../../dashboard/dashboard_navigation.dart';
import '../../dashboard/native_dashboard_layout.dart';
import '../unit_schedule/unit_appointment_models.dart';

/// AllAppointment is a Manager entry, or a child of Admin AppointmentModify.
bool allAppointmentAllowed(AccountProfile profile) =>
    profile.isDoctor
        ? profile.value('doc_manager_flag') == '1'
        : nativeDashboardRoute(profile, DashboardDestination.appointment) !=
            null;

bool allAppointmentMayCall(AccountProfile profile, UnitAppointmentSlot slot) =>
    !profile.isDoctor &&
    profile.value('all_access_flag') == '1' &&
    slot.booked &&
    slot.value('pat_cell').isNotEmpty;

Uri allAppointmentPhoneUri(UnitAppointmentSlot slot) =>
    Uri(scheme: 'tel', path: slot.value('pat_cell'));

String allAppointmentScope(AccountProfile profile) => [
  profile.role.name,
  profile.doctorId,
  profile.value('doc_code'),
  profile.value('doc_manager_flag'),
  profile.value('deptd_id'),
  profile.value('depts_id'),
  profile.value('usr_id'),
  profile.value('usr_name'),
  profile.value('all_access_flag'),
  profile.value('hr_appointment_active'),
  profile.value('acc_appointment_active'),
].join('|');

class AllAppointmentUnavailable implements Exception {
  const AllAppointmentUnavailable();
}

enum AllAppointmentFilter { department, unit, doctor }

/// Retry resumes the failed native GET stage without reloading earlier stages.
enum AllAppointmentLoad { departments, units, totals, doctors }

class AllAppointmentTotals {
  const AllAppointmentTotals(this.appointments, this.blank);
  static const zero = AllAppointmentTotals(0, 0);
  factory AllAppointmentTotals.fromData(JsonMap row) {
    int count(String key) {
      if (!row.containsKey(key)) {
        throw const AppFailure(
          'The server returned incomplete department totals.',
        );
      }
      final value = int.tryParse(nativeText(row[key], '0'));
      if (value == null || value < 0) {
        throw const AppFailure(
          'The server returned invalid department totals.',
        );
      }
      return value;
    }

    final appointments = count('deptd_sch_count');
    final total = count('deptd_tot_count'), busy = count('deptd_busy_count');
    return AllAppointmentTotals(
      appointments,
      total == 0 ? 0 : total - appointments - busy,
    );
  }
  final int appointments, blank;
}
