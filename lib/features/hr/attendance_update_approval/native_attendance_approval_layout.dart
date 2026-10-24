import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import 'attendance_approval_models.dart';

TextStyle attendanceApprovalText(
  double size, {
  String family = 'Poppins',
  FontWeight weight = FontWeight.w600,
  Color color = Colors.black,
}) => TextStyle(
  fontFamily: family,
  fontFamilyFallback: const ['DocDiaryBengali'],
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1.5,
);

double attendanceApprovalScale(BuildContext context) {
  final width = MediaQuery.sizeOf(context).shortestSide;
  return width < 300 ? 1 : (width / 30).floor() * 30 / 300;
}

const _fieldFill = Color(0xfff5f5f5);
const _labelColor = Color(0xff9e9e9e);
const _textColor = Color(0xff6c6e6f);

class NativeAttendanceApprovalLayout extends StatelessWidget {
  const NativeAttendanceApprovalLayout({
    super.key,
    required this.onBack,
    required this.onSelect,
    required this.onAction,
    required this.comments,
    this.request,
    this.detail,
    this.waiting = false,
    this.enabled = true,
    this.message,
  });
  final VoidCallback onBack, onSelect;
  final ValueChanged<AttendanceApprovalAction> onAction;
  final TextEditingController comments;
  final AttendanceApprovalRequest? request;
  final AttendanceApprovalDetail? detail;
  final bool waiting, enabled;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final sdp = attendanceApprovalScale(context);
    final active = enabled && !waiting && message == null;
    final data = detail;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: DocColors.primary,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(12 * sdp),
                child: Row(
                  children: [
                    SizedBox(width: 12 * sdp),
                    IconButton(
                      key: const Key('attendance_approval_back'),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: 19 * sdp,
                        height: 19 * sdp,
                      ),
                      onPressed: !waiting ? onBack : null,
                      color: Colors.white,
                      disabledColor: Colors.white54,
                      icon: Icon(Icons.arrow_back_ios, size: 19 * sdp),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Attendance Update Approval',
                        style: attendanceApprovalText(
                          13 * sdp,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  child: ColoredBox(
                    color: Colors.white,
                    child: SafeArea(
                      top: false,
                      child:
                          waiting
                              ? const Center(
                                child: CircularProgressIndicator(
                                  key: Key('attendance_approval_loading'),
                                ),
                              )
                              : message != null
                              ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    message!,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                              : Padding(
                                // Rounded MaterialCardView insets its native children in
                                // addition to the margins specified in the screen XML.
                                padding: const EdgeInsets.fromLTRB(
                                  8.8,
                                  8.8,
                                  8.8,
                                  0,
                                ),
                                child: _ShortViewport(
                                  child: Column(
                                    children: [
                                      _RequestCode(
                                        request: request,
                                        enabled: active,
                                        onSelect: onSelect,
                                        sdp: sdp,
                                      ),
                                      if (data != null) ...[
                                        Expanded(
                                          child: Card(
                                            key: const Key(
                                              'attendance_approval_detail_card',
                                            ),
                                            color: Colors.white,
                                            elevation: 3,
                                            margin: EdgeInsets.fromLTRB(
                                              4 * sdp,
                                              8 * sdp,
                                              4 * sdp,
                                              4 * sdp,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    8 * sdp,
                                                  ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    8 * sdp,
                                                  ),
                                              child: SingleChildScrollView(
                                                key: const Key(
                                                  'attendance_approval_details',
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 2 * sdp,
                                                ),
                                                child: _Details(
                                                  data: data,
                                                  comments: comments,
                                                  enabled: active,
                                                  sdp: sdp,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        _Actions(
                                          sdp: sdp,
                                          enabled: active,
                                          onAction: onAction,
                                        ),
                                      ] else
                                        const Spacer(),
                                    ],
                                  ),
                                ),
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

class _RequestCode extends StatelessWidget {
  const _RequestCode({
    required this.request,
    required this.enabled,
    required this.onSelect,
    required this.sdp,
  });
  final AttendanceApprovalRequest? request;
  final bool enabled;
  final VoidCallback onSelect;
  final double sdp;
  @override
  Widget build(BuildContext context) => Card(
    color: DocColors.primary,
    elevation: 1,
    margin: EdgeInsets.all(4 * sdp),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8 * sdp)),
    child: Padding(
      padding: const EdgeInsets.all(1),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8 * sdp),
        child: InkWell(
          key: const Key('attendance_approval_select'),
          onTap: enabled ? onSelect : null,
          borderRadius: BorderRadius.circular(8 * sdp),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 40 * sdp),
            child: Row(
              children: [
                const SizedBox(
                  width: 48,
                  child: Icon(Icons.search, size: 24, color: Colors.black),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(4, 6 * sdp, 12, 6 * sdp),
                    child:
                        request == null
                            ? Text(
                              'Select Attendance Update Request Code',
                              style: attendanceApprovalText(
                                10 * sdp,
                                family: 'OpenSans',
                                weight: FontWeight.w700,
                                color: _textColor,
                              ).copyWith(height: 1.25),
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Attendance Update Request Code',
                                  key: const Key(
                                    'attendance_approval_code_label',
                                  ),
                                  style: attendanceApprovalText(
                                    10 * sdp,
                                    family: 'OpenSans',
                                    weight: FontWeight.w700,
                                    color: _textColor,
                                  ).copyWith(height: 1.25),
                                ),
                                Text(
                                  request!.code,
                                  style: attendanceApprovalText(
                                    10 * sdp,
                                    family: 'OpenSans',
                                    weight: FontWeight.w700,
                                  ).copyWith(height: 1.25),
                                ),
                              ],
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Details extends StatelessWidget {
  const _Details({
    required this.data,
    required this.comments,
    required this.enabled,
    required this.sdp,
  });
  final AttendanceApprovalDetail data;
  final TextEditingController comments;
  final bool enabled;
  final double sdp;
  Widget field(
    String label,
    String key, {
    double size = 11,
    double minHeight = 44,
    IconData? icon,
    EdgeInsets? margin,
  }) => Padding(
    padding: margin ?? EdgeInsets.all(4 * sdp),
    child: _ReadField(
      label: label,
      value: data.value(key),
      sdp: sdp,
      size: size,
      minHeight: minHeight,
      icon: icon,
      fieldKey: Key('attendance_approval_field_$key'),
    ),
  );
  Widget pair(String label, String key) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        flex: 3,
        child: Padding(
          padding: EdgeInsets.all(4 * sdp),
          child: Text(
            label,
            style: attendanceApprovalText(10 * sdp, color: _textColor),
          ),
        ),
      ),
      Expanded(
        flex: 7,
        child: Padding(
          padding: EdgeInsets.all(4 * sdp),
          child: Container(
            key: Key('attendance_approval_field_$key'),
            constraints: BoxConstraints(minHeight: 44 * sdp),
            padding: EdgeInsets.symmetric(
              horizontal: 12 * sdp,
              vertical: 8 * sdp,
            ),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: _fieldFill,
              borderRadius: BorderRadius.circular(4 * sdp),
            ),
            child: Text(
              data.value(key),
              textAlign: TextAlign.end,
              style: attendanceApprovalText(11 * sdp),
            ),
          ),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 55,
              child: field(
                'Name:',
                'emp_name',
                size: 8,
                minHeight: 38,
                margin: EdgeInsets.fromLTRB(4 * sdp, 4 * sdp, 0, 4 * sdp),
              ),
            ),
            Expanded(
              flex: 30,
              child: field(
                'ID:',
                'emp_code',
                size: 8,
                minHeight: 38,
                margin: EdgeInsets.fromLTRB(4 * sdp, 4 * sdp, 0, 4 * sdp),
              ),
            ),
            Expanded(
              flex: 35,
              child: field('Date:', 'darm_date', size: 8, minHeight: 38),
            ),
          ],
        ),
      ),
      field(
        'Calling Title:',
        'job_calling_title',
        size: 8,
        minHeight: 38,
        margin: EdgeInsets.fromLTRB(4 * sdp, 0, 4 * sdp, 4 * sdp),
      ),
      const _Separator(),
      SizedBox(height: 4 * sdp),
      pair('Request Type:', 'darm_req_type'),
      pair('Shift to be Updated:', 'shift'),
      const _Separator(),
      field(
        'Date to be Updated:',
        'darm_update_date',
        icon: Icons.calendar_month,
      ),
      Padding(
        padding: EdgeInsets.all(4 * sdp),
        child: Text(
          'Time to be Updated:',
          textAlign: TextAlign.center,
          style: attendanceApprovalText(10 * sdp, color: _textColor),
        ),
      ),
      if (data.hasIn || data.hasOut)
        Row(
          key: const Key('attendance_approval_times'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.hasIn)
              Expanded(
                child: field(
                  'In Time:',
                  'arrival_time',
                  size: 10,
                  minHeight: 42,
                  icon: Icons.access_time,
                ),
              ),
            if (data.hasOut)
              Expanded(
                child: field(
                  'Out Time:',
                  'departure_time',
                  size: 10,
                  minHeight: 42,
                  icon: Icons.access_time,
                ),
              ),
          ],
        ),
      const _Separator(),
      pair('Machine In Time:', 'mac_in_time'),
      pair('Machine Out Time:', 'mac_out_time'),
      pair('Current Shift:', 'current_shift'),
      const _Separator(),
      pair('Reason Type:', 'reason'),
      field('Reason Description:', 'darm_reason'),
      const _Separator(),
      Padding(
        padding: EdgeInsets.all(4 * sdp),
        child: TextField(
          key: const Key('attendance_approval_comments'),
          controller: comments,
          enabled: enabled,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          style: attendanceApprovalText(11 * sdp),
          autocorrect: false,
          enableSuggestions: false,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(
            labelText:
                comments.text.isEmpty
                    ? 'Write Approve/Reject Comments:'
                    : 'Approve/Reject Comments:',
            labelStyle: attendanceApprovalText(10 * sdp, color: _textColor),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16 * sdp,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8 * sdp),
              borderSide: const BorderSide(color: Color(0xff0984e3), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8 * sdp),
              borderSide: const BorderSide(color: Color(0xff0984e3)),
            ),
          ),
        ),
      ),
      SizedBox(height: 8 * sdp),
      if (data.hasForwarder)
        Column(
          key: const Key('attendance_approval_forwarded'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Separator(),
            field('Forwarded By:', 'forwarder_name'),
            field('Forward Comment:', 'dard_recommendation'),
          ],
        ),
      SizedBox(height: 8 * sdp),
    ],
  );
}

class _ReadField extends StatelessWidget {
  const _ReadField({
    required this.label,
    required this.value,
    required this.sdp,
    required this.size,
    required this.minHeight,
    required this.fieldKey,
    this.icon,
  });
  final String label, value;
  final double sdp, size, minHeight;
  final Key fieldKey;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    key: fieldKey,
    constraints: BoxConstraints(minHeight: minHeight * sdp),
    decoration: BoxDecoration(
      color: _fieldFill,
      borderRadius: BorderRadius.circular(4 * sdp),
    ),
    padding: EdgeInsets.symmetric(vertical: 6 * sdp),
    child: Row(
      children: [
        if (icon != null)
          SizedBox(
            width: 48,
            child: Icon(icon, size: 24, color: DocColors.primary),
          ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: icon == null ? 12 * sdp : 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: attendanceApprovalText(
                    9 * sdp,
                    color: _labelColor,
                  ).copyWith(height: 1.25),
                ),
                Text(
                  value,
                  style: attendanceApprovalText(
                    size * sdp,
                  ).copyWith(height: 1.25),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Separator extends StatelessWidget {
  const _Separator();
  @override
  Widget build(BuildContext context) => const Text(
    '- - - - - - - - - - - -',
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 13,
      color: _textColor,
      height: 1.3,
    ),
  );
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.sdp,
    required this.enabled,
    required this.onAction,
  });
  final double sdp;
  final bool enabled;
  final ValueChanged<AttendanceApprovalAction> onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 8 * sdp),
    child: Row(
      children: [
        for (final action in AttendanceApprovalAction.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(4 * sdp),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(10),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [DocColors.primary, DocColors.greenSea],
                    ),
                  ),
                  child: InkWell(
                    key: Key('attendance_approval_${action.name}'),
                    onTap: enabled ? () => onAction(action) : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 10 * sdp,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        action.label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: attendanceApprovalText(
                          10 * sdp,
                          family: 'RussoOne',
                          weight: FontWeight.w400,
                          color: Colors.white,
                        ).copyWith(height: 1.25),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Keep the main composition accessible when the keyboard or landscape makes
/// the viewport shorter than the request selector and the pinned action row.
class _ShortViewport extends StatelessWidget {
  const _ShortViewport({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder:
        (context, bounds) => SingleChildScrollView(
          child: SizedBox(
            height: bounds.maxHeight < 320 ? 320 : bounds.maxHeight,
            child: child,
          ),
        ),
  );
}
