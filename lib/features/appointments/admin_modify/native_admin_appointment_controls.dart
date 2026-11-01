import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import '../../../core/native_dates.dart';
import '../../profile/native_profile_icons.dart';
import '../../reports/native_report_icons.dart';
import '../doctor_schedule/native_appointment_timeline_card.dart';
import 'admin_appointment_models.dart';

double adminAppointmentScale(BuildContext context) => appointmentScale(context);
TextStyle adminAppointmentText(
  double size,
  double scale, {
  String family = 'Poppins',
  FontWeight weight = FontWeight.w400,
  Color color = Colors.black,
}) => TextStyle(
  inherit: false,
  textBaseline: TextBaseline.alphabetic,
  fontFamily: family,
  fontFamilyFallback: const ['DocDiaryBengali'],
  fontSize: math.max(8, size * scale - 1),
  fontWeight: weight,
  color: color,
  height: 1.4,
);

class NativeAdminAppointmentShell extends StatelessWidget {
  const NativeAdminAppointmentShell({
    super.key,
    required this.child,
    required this.onBack,
    this.onAll,
    this.title = 'Appointment',
    this.editor = false,
  });
  final Widget child;
  final VoidCallback onBack;
  final VoidCallback? onAll;
  final String title;
  final bool editor;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: editor ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: editor ? DocColors.clouds : DocColors.primary,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * s,
                  vertical: 7 * s,
                ),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('admin_appointment_back'),
                      tooltip: editor ? 'Close' : 'Back',
                      onPressed: onBack,
                      padding: EdgeInsets.zero,
                      icon:
                          editor
                              ? NativeReportIcon(
                                ReportGlyph.close,
                                size: 21 * s,
                                color: Colors.black,
                              )
                              : NativeProfileIcon(
                                NativeProfileGlyph.back,
                                size: 19 * s,
                                color: Colors.white,
                              ),
                    ),
                    SizedBox(width: 8 * s),
                    Expanded(
                      child: Text(
                        title,
                        style: adminAppointmentText(
                          14,
                          s,
                          weight: FontWeight.w700,
                          color: editor ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                    if (!editor)
                      Padding(
                        padding: EdgeInsets.only(left: 4 * s),
                        child: TextButton(
                          key: const Key('admin_appointment_view_all'),
                          onPressed: onAll,
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xfffda000),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(64, 36),
                            padding: EdgeInsets.symmetric(horizontal: 12 * s),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12 * s),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2.0),
                            child: Text(
                              'VIEW ALL',
                              style: adminAppointmentText(
                                9,
                                s,
                                family: 'RussoOne',
                                color: Colors.white,
                                weight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (editor)
                const SizedBox(
                  height: 1,
                  child: ColoredBox(
                    color: DocColors.greenSea,
                    child: SizedBox.expand(),
                  ),
                )
              else
                const SizedBox(height: 5),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        editor
                            ? BorderRadius.zero
                            : const BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filled white native card, its 1dp teal surround and Archivo value. Unit/Qty
/// are display-only fields; the selected value does not change their label.
class NativeAdminAppointmentField extends StatelessWidget {
  const NativeAdminAppointmentField({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.enabled = true,
    this.search = false,
    this.calendar = false,
    this.dropdown = true,
  });
  final String label, value;
  final VoidCallback? onTap;
  final bool enabled, search, calendar, dropdown;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context),
        radius = BorderRadius.circular(10);
    return Semantics(
      button: onTap != null,
      enabled: enabled,
      label: '$label${value.isEmpty ? '' : ': $value'}',
      child: Material(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: DocColors.primary),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: InputDecorator(
              isEmpty: value.isEmpty,
              decoration: InputDecoration(
                enabled: enabled,
                labelText: label,
                labelStyle: adminAppointmentText(
                  11,
                  s,
                  family: 'Roboto',
                  color: const Color(0xff7e8284),
                ),
                floatingLabelStyle: adminAppointmentText(
                  11.5,
                  s,
                  family: 'Roboto',
                  color: const Color(0xff7e8284),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12 * s,
                  vertical: 10 * s,
                ),
                filled: true,
                fillColor: Colors.white,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixIcon:
                    search
                        ? const Icon(Icons.search, color: Colors.black)
                        : calendar
                        ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: NativeReportIcon(
                            ReportGlyph.calendar,
                            size: 24,
                            color: DocColors.primary,
                          ),
                        )
                        : null,
                suffixIcon:
                    dropdown && !search && !calendar
                        ? Icon(
                          Icons.arrow_drop_down,
                          color:
                              enabled
                                  ? const Color(0xff6c6e6f)
                                  : const Color(0xffb2bec3),
                        )
                        : null,
              ),
              child: Text(
                value,
                style: adminAppointmentText(
                  11,
                  s,
                  family: 'Archivo',
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NativeAdminAppointmentButton extends StatelessWidget {
  const NativeAdminAppointmentButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(10),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [DocColors.primary, DocColors.greenSea],
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Center(
              child: Text(
                label,
                style: adminAppointmentText(
                  13,
                  adminAppointmentScale(context),
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class NativeAdminAppointmentTableRow extends StatelessWidget {
  const NativeAdminAppointmentTableRow({
    super.key,
    required this.cells,
    required this.weights,
    this.header = false,
    this.onTap,
    this.fontSize = 8,
  });
  final List<String> cells;
  final List<int> weights;
  final bool header;
  final VoidCallback? onTap;
  final double fontSize;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cells.length; i++)
                Expanded(
                  flex: weights[i],
                  child: Container(
                    margin: EdgeInsets.only(
                      left: i == 0 ? 0 : 2,
                      right: i + 1 == cells.length ? 0 : 2,
                    ),
                    padding: const EdgeInsets.all(4),
                    color: header ? DocColors.primary : DocColors.clouds,
                    child: Center(
                      child: Text(
                        cells[i],
                        textAlign: TextAlign.center,
                        style: adminAppointmentText(
                          header ? 9 : fontSize,
                          s,
                          family: header ? 'PatuaOne' : 'OpenSans',
                          weight: header ? FontWeight.w400 : FontWeight.w700,
                          color:
                              header ? Colors.white : const Color(0xff6c6e6f),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NativeAdminTakenTimes extends StatelessWidget {
  const NativeAdminTakenTimes({
    super.key,
    required this.label,
    required this.times,
  });
  final String label;
  final List<String> times;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(4 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: adminAppointmentText(
                11,
                s,
                weight: FontWeight.w700,
                color: DocColors.greenSea,
              ),
            ),
            for (final row in times)
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  row,
                  style: adminAppointmentText(
                    9,
                    s,
                    family: 'OpenSans',
                    weight: FontWeight.w700,
                    color: const Color(0xff6c6e6f),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Same Material date presentation as the app, with the native selectable-day
/// list and Saturday-first calendar scoped to this one dialog.
class NativeAdminScheduleDateDialog extends StatelessWidget {
  const NativeAdminScheduleDateDialog({
    super.key,
    required this.days,
    required this.now,
  });
  final List<AdminAppointmentDay> days;
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final sorted = days.map((d) => d.date).toList()..sort();
    final chosen =
        sorted.contains(dateOnly(now)) ? dateOnly(now) : sorted.first;
    final theme = Theme.of(context);
    return Localizations.override(
      context: context,
      locale: const Locale('en', 'US'),
      delegates: const [_SaturdayDelegate()],
      child: Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: DocColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
          datePickerTheme: const DatePickerThemeData(
            backgroundColor: Colors.white,
            headerBackgroundColor: DocColors.primary,
            headerForegroundColor: Colors.white,
          ),
        ),
        child: DatePickerDialog(
          key: const Key('admin_schedule_date_dialog'),
          initialDate: chosen,
          firstDate: DateTime(sorted.first.year, sorted.first.month),
          lastDate: DateTime(sorted.last.year, sorted.last.month + 1, 0),
          currentDate: now,
          initialEntryMode: DatePickerEntryMode.calendarOnly,
          selectableDayPredicate: (d) => sorted.contains(dateOnly(d)),
        ),
      ),
    );
  }
}

class _SaturdayLocalization extends DefaultMaterialLocalizations {
  @override
  int get firstDayOfWeekIndex => 6;
}

class _SaturdayDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _SaturdayDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(_SaturdayLocalization());
  @override
  bool shouldReload(_SaturdayDelegate old) => false;
}
