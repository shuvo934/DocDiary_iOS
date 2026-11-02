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
  // OpenSans is a variable font registered at its regular weight. Select its
  // native bold axis explicitly instead of relying on synthetic font matching.
  fontVariations:
      family == 'OpenSans'
          ? [FontVariation('wght', weight.value.toDouble())]
          : null,
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
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 40,
                      ),
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
                        padding: EdgeInsets.only(left: 4 * s, right: 4 * s),
                        child: TextButton(
                          key: const Key('admin_appointment_view_all'),
                          onPressed: onAll,
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xfffda000),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(64, 36),
                            elevation: 1,
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
                              ).copyWith(letterSpacing: 1.25),
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
                  child:
                      editor
                          ? child
                          : Padding(
                            // MaterialCardView's native rounded-corner content inset.
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                            child: child,
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
    this.boldLabel = false,
    this.center = false,
    this.multiline = false,
  });
  final String label, value;
  final VoidCallback? onTap;
  final bool enabled, search, calendar, dropdown, boldLabel, center, multiline;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context),
        radius = BorderRadius.circular(10);
    final fill = enabled ? Colors.white : const Color(0xfff5f5f5);
    final labelWeight =
        boldLabel || calendar || search ? FontWeight.w700 : FontWeight.w400;
    final labelColor =
        enabled ? const Color(0xff6c6e6f) : const Color(0xff999999);
    return Semantics(
      button: onTap != null,
      enabled: enabled,
      label: '$label${value.isEmpty ? '' : ': $value'}',
      child: Material(
        color: fill,
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
              textAlign: center ? TextAlign.center : TextAlign.start,
              decoration: InputDecoration(
                enabled: enabled,
                floatingLabelAlignment:
                    center
                        ? FloatingLabelAlignment.center
                        : FloatingLabelAlignment.start,
                labelText: label,
                labelStyle: adminAppointmentText(
                  11,
                  s,
                  family: 'Roboto',
                  color: labelColor,
                  weight: labelWeight,
                ),
                floatingLabelStyle: adminAppointmentText(
                  11.5,
                  s,
                  family: 'Roboto',
                  color: labelColor,
                  weight: labelWeight,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12 * s,
                  vertical: 10 * s,
                ),
                filled: true,
                fillColor: fill,
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
                            color: const Color(0xfffda000),
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
                                  : const Color(0xff999999),
                        )
                        : null,
              ),
              child: Text(
                value,
                textAlign: center ? TextAlign.center : TextAlign.start,
                maxLines: multiline ? null : 1,
                overflow: multiline ? TextOverflow.clip : TextOverflow.ellipsis,
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
    this.fontSize = 13,
    this.enabled = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final double fontSize;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    elevation: 2,
    borderRadius: BorderRadius.circular(10),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              enabled
                  ? [DocColors.primary, DocColors.greenSea]
                  : [Color(0xffb2bec3), Color(0xffb2bec3)],
        ),
      ),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Center(
              child: Text(
                label,
                style: adminAppointmentText(
                  fontSize,
                  adminAppointmentScale(context),
                  weight: FontWeight.w700,
                  color: Colors.white,
                ).copyWith(letterSpacing: 1.25),
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
    this.headerFontSize = 9,
  });
  final List<String> cells;
  final List<int> weights;
  final bool header;
  final VoidCallback? onTap;
  final double fontSize, headerFontSize;
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
                          header ? headerFontSize : fontSize,
                          s,
                          family: header ? 'PatuaOne' : 'OpenSans',
                          weight: header ? FontWeight.w400 : FontWeight.w700,
                          color:
                              header ? Colors.white : const Color(0xff6c6e6f),
                        ).copyWith(
                          fontSize: math.max(
                            8,
                            (header ? headerFontSize : fontSize) * s,
                          ),
                          height: header ? 1.3 : 1.4,
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
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      color: DocColors.clouds,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4 * s, 7 * s, 4 * s, 5 * s),
              child: Text(
                label,
                style: adminAppointmentText(
                  11,
                  s,
                  weight: FontWeight.w700,
                  color: DocColors.greenSea,
                ),
              ),
            ),
            for (final row in times)
              Padding(
                padding: EdgeInsets.fromLTRB(10 * s, 4 * s, 10 * s, 4 * s),
                child: Text(
                  row,
                  style: adminAppointmentText(
                    10,
                    s,
                    weight: FontWeight.w700,
                    color: Colors.black,
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
