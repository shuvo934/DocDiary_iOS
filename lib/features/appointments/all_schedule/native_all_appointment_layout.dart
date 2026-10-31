import 'package:flutter/material.dart';
import '../doctor_schedule/doctor_appointment_models.dart';
import '../doctor_schedule/native_appointment_timeline_card.dart';
import '../unit_schedule/native_unit_appointment_layout.dart';
import '../unit_schedule/unit_appointment_models.dart';

/// AllAppointment reuses the same native DoctorsListAdapter and slot layout.
class NativeAllAppointmentLayout extends StatelessWidget {
  const NativeAllAppointmentLayout({
    super.key,
    required this.window,
    required this.selected,
    required this.now,
    required this.departments,
    required this.units,
    required this.department,
    required this.unit,
    required this.doctor,
    required this.rows,
    required this.doctorCount,
    required this.hasDoctors,
    required this.generation,
    required this.scroll,
    required this.onBack,
    required this.onDepartment,
    required this.onUnit,
    required this.onDoctor,
    required this.onDepartmentStats,
    required this.onUnitStats,
    required this.onDate,
    required this.onMonth,
    this.onCall,
    this.busy = false,
    this.enabled = true,
    this.message,
  });
  final DoctorAppointmentWindow window;
  final DateTime selected, now;
  final List<UnitAppointmentChoice> departments, units;
  final UnitAppointmentChoice? department, unit, doctor;
  final List<UnitAppointmentDoctor> rows;
  final int doctorCount, generation;
  final ScrollController scroll;
  final bool hasDoctors, busy, enabled;
  final String? message;
  final VoidCallback onBack, onDepartmentStats, onUnitStats;
  final ValueChanged<Rect> onDepartment, onUnit, onDoctor;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<int> onMonth;
  final ValueChanged<UnitAppointmentSlot>? onCall;
  @override
  Widget build(BuildContext context) {
    final sdp = appointmentScale(context);
    final active = enabled && !busy && message == null;
    return NativeUnitAppointmentLayout(
      title: 'All Appointment',
      keyPrefix: 'all_appointment',
      controlsMargin: 0,
      leadingFilter: Padding(
        padding: EdgeInsets.fromLTRB(4 * sdp, 0, 4 * sdp, 5 * sdp),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 8,
                child: NativeScheduleSelectionField(
                  fieldKey: const Key('all_appointment_department'),
                  label:
                      department == null ? 'Select Department' : 'Department',
                  value: department?.name ?? '',
                  sdp: sdp,
                  onTap: active && departments.isNotEmpty ? onDepartment : null,
                ),
              ),
              SizedBox(width: 8 * sdp),
              Expanded(
                flex: 2,
                child: NativeScheduleTotalsButton(
                  tapKey: const Key('all_appointment_department_totals'),
                  sdp: sdp,
                  onTap: active ? onDepartmentStats : null,
                ),
              ),
            ],
          ),
        ),
      ),
      window: window,
      selected: selected,
      now: now,
      units: units,
      unit: unit,
      unitLabel: 'Unit',
      unitEnabled: department != null,
      doctor: doctor,
      doctorEnabled: unit != null && hasDoctors,
      rows: rows,
      doctorCount: doctorCount,
      hasDoctors: true,
      generation: generation,
      scroll: scroll,
      emptyMessage:
          unit == null
              ? 'Select Unit to View Doctor/Therapist Schedule'
              : 'No Doctor/Therapist Found',
      busy: busy,
      enabled: enabled,
      message: message,
      onBack: onBack,
      onUnit: onUnit,
      onDoctor: onDoctor,
      onStats: onUnitStats,
      onDate: onDate,
      onMonth: onMonth,
      onCall: onCall,
    );
  }
}
