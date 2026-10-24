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
    Widget pair(String label, String key) => Padding(
      padding: EdgeInsets.symmetric(horizontal: 12 * sdp, vertical: 5 * sdp),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: attendanceApprovalText(
                9 * sdp,
                color: const Color(0xff6c6e6f),
              ),
            ),
          ),
          SizedBox(width: 8 * sdp),
          Expanded(
            flex: 7,
            child: Text(
              data!.value(key),
              textAlign: TextAlign.end,
              style: attendanceApprovalText(10 * sdp),
            ),
          ),
        ],
      ),
    );
    Widget field(String label, String key, {double size = 10}) =>
        _ReadField(label: label, value: data!.value(key), sdp: sdp, size: size);
    Widget dash() => Padding(
      padding: EdgeInsets.symmetric(vertical: 4 * sdp),
      child: const Text('- - - - - - - - - - - -', textAlign: TextAlign.center),
    );
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
                    IconButton(
                      key: const Key('attendance_approval_back'),
                      onPressed: !waiting ? onBack : null,
                      color: Colors.white,
                      disabledColor: Colors.white54,
                      icon: Icon(Icons.arrow_back_ios_new, size: 19 * sdp),
                    ),
                    const SizedBox(width: 8),
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
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20 * sdp),
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
                              : _ShortViewport(
                                child: Column(
                                  children: [
                                    Card(
                                      elevation: 2,
                                      color: DocColors.primary,
                                      margin: EdgeInsets.all(4 * sdp),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          8 * sdp,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(1),
                                        child: InkWell(
                                          key: const Key(
                                            'attendance_approval_select',
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8 * sdp,
                                          ),
                                          onTap: active ? onSelect : null,
                                          child: InputDecorator(
                                            isEmpty: request == null,
                                            decoration: InputDecoration(
                                              labelText:
                                                  request == null
                                                      ? 'Select Attendance Update Request Code'
                                                      : 'Attendance Update Request Code',
                                              labelStyle:
                                                  attendanceApprovalText(
                                                    10 * sdp,
                                                    family: 'OpenSans',
                                                    weight: FontWeight.w400,
                                                    color: const Color(
                                                      0xff6c6e6f,
                                                    ),
                                                  ),
                                              prefixIcon: const Icon(
                                                Icons.search,
                                                color: Colors.black,
                                              ),
                                              fillColor: Colors.white,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 12 * sdp,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      8 * sdp,
                                                    ),
                                                borderSide: BorderSide.none,
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      8 * sdp,
                                                    ),
                                                borderSide: BorderSide.none,
                                              ),
                                            ),
                                            child: Text(
                                              request?.code ?? '',
                                              style: attendanceApprovalText(
                                                9 * sdp,
                                                family: 'OpenSans',
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (data != null) ...[
                                      Expanded(
                                        child: Card(
                                          elevation: 2,
                                          margin: EdgeInsets.fromLTRB(
                                            4 * sdp,
                                            8 * sdp,
                                            4 * sdp,
                                            4 * sdp,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8 * sdp,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8 * sdp,
                                            ),
                                            child: SingleChildScrollView(
                                              key: const Key(
                                                'attendance_approval_details',
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                vertical: 2 * sdp,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Expanded(
                                                        flex: 55,
                                                        child: field(
                                                          'Name:',
                                                          'emp_name',
                                                          size: 7,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 30,
                                                        child: field(
                                                          'ID:',
                                                          'emp_code',
                                                          size: 7,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 35,
                                                        child: field(
                                                          'Date:',
                                                          'darm_date',
                                                          size: 7,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  field(
                                                    'Calling Title:',
                                                    'job_calling_title',
                                                    size: 7,
                                                  ),
                                                  dash(),
                                                  pair(
                                                    'Request Type:',
                                                    'darm_req_type',
                                                  ),
                                                  pair(
                                                    'Shift to be Updated:',
                                                    'shift',
                                                  ),
                                                  dash(),
                                                  field(
                                                    'Date to be Updated:',
                                                    'darm_update_date',
                                                  ),
                                                  Padding(
                                                    padding: EdgeInsets.only(
                                                      top: 4 * sdp,
                                                    ),
                                                    child: Text(
                                                      'Time to be Updated:',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style:
                                                          attendanceApprovalText(
                                                            10 * sdp,
                                                            color: const Color(
                                                              0xff6c6e6f,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                  if (data.hasIn || data.hasOut)
                                                    Row(
                                                      key: const Key(
                                                        'attendance_approval_times',
                                                      ),
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        if (data.hasIn)
                                                          Expanded(
                                                            child: field(
                                                              'In Time:',
                                                              'arrival_time',
                                                              size: 9,
                                                            ),
                                                          ),
                                                        if (data.hasOut)
                                                          Expanded(
                                                            child: field(
                                                              'Out Time:',
                                                              'departure_time',
                                                              size: 9,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  dash(),
                                                  pair(
                                                    'Machine In Time:',
                                                    'mac_in_time',
                                                  ),
                                                  pair(
                                                    'Machine Out Time:',
                                                    'mac_out_time',
                                                  ),
                                                  pair(
                                                    'Current Shift:',
                                                    'current_shift',
                                                  ),
                                                  dash(),
                                                  pair(
                                                    'Reason Type:',
                                                    'reason',
                                                  ),
                                                  field(
                                                    'Reason Description:',
                                                    'darm_reason',
                                                  ),
                                                  dash(),
                                                  Padding(
                                                    padding: EdgeInsets.all(
                                                      4 * sdp,
                                                    ),
                                                    child: TextField(
                                                      key: const Key(
                                                        'attendance_approval_comments',
                                                      ),
                                                      controller: comments,
                                                      enabled: active,
                                                      textInputAction:
                                                          TextInputAction.done,
                                                      onSubmitted:
                                                          (_) =>
                                                              FocusScope.of(
                                                                context,
                                                              ).unfocus(),
                                                      style:
                                                          attendanceApprovalText(
                                                            10 * sdp,
                                                          ),
                                                      decoration: InputDecoration(
                                                        labelText:
                                                            comments
                                                                    .text
                                                                    .isEmpty
                                                                ? 'Write Approve/Reject Comments:'
                                                                : 'Approve/Reject Comments:',
                                                        labelStyle:
                                                            attendanceApprovalText(
                                                              10 * sdp,
                                                              weight:
                                                                  FontWeight
                                                                      .w400,
                                                              color:
                                                                  const Color(
                                                                    0xff6c6e6f,
                                                                  ),
                                                            ),
                                                        fillColor: Colors.white,
                                                        contentPadding:
                                                            EdgeInsets.all(
                                                              10 * sdp,
                                                            ),
                                                        border:
                                                            const UnderlineInputBorder(),
                                                        enabledBorder:
                                                            const UnderlineInputBorder(
                                                              borderSide:
                                                                  BorderSide(
                                                                    color:
                                                                        Colors
                                                                            .black38,
                                                                  ),
                                                            ),
                                                        focusedBorder:
                                                            const UnderlineInputBorder(
                                                              borderSide: BorderSide(
                                                                color:
                                                                    DocColors
                                                                        .primary,
                                                              ),
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (data.hasForwarder)
                                                    Column(
                                                      key: const Key(
                                                        'attendance_approval_forwarded',
                                                      ),
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: [
                                                        dash(),
                                                        field(
                                                          'Forwarded By:',
                                                          'forwarder_name',
                                                        ),
                                                        field(
                                                          'Forward Comment:',
                                                          'dard_recommendation',
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(4 * sdp),
                                        child: Row(
                                          children: [
                                            for (final action
                                                in AttendanceApprovalAction
                                                    .values)
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsets.all(
                                                    4 * sdp,
                                                  ),
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      gradient:
                                                          const LinearGradient(
                                                            colors: [
                                                              DocColors.primary,
                                                              DocColors
                                                                  .greenSea,
                                                            ],
                                                          ),
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        key: Key(
                                                          'attendance_approval_${action.name}',
                                                        ),
                                                        onTap:
                                                            active
                                                                ? () =>
                                                                    onAction(
                                                                      action,
                                                                    )
                                                                : null,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 7,
                                                                vertical:
                                                                    12 * sdp,
                                                              ),
                                                          child: Text(
                                                            action.label
                                                                .toUpperCase(),
                                                            textAlign:
                                                                TextAlign
                                                                    .center,
                                                            style:
                                                                attendanceApprovalText(
                                                                  9 * sdp,
                                                                  family:
                                                                      'RussoOne',
                                                                  weight:
                                                                      FontWeight
                                                                          .w400,
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                ),
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
                                    ] else
                                      const Spacer(),
                                  ],
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

/// Keep the portrait composition, allowing the whole body to scroll when a
/// landscape viewport or the keyboard leaves too little room for fixed buttons.
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

class _ReadField extends StatelessWidget {
  const _ReadField({
    required this.label,
    required this.value,
    required this.sdp,
    required this.size,
  });
  final String label, value;
  final double sdp, size;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(4 * sdp),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * sdp, vertical: 5 * sdp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: attendanceApprovalText(
              9 * sdp,
              weight: FontWeight.w400,
              color: const Color(0xff6c6e6f),
            ),
          ),
          SizedBox(height: 3 * sdp),
          Text(value, style: attendanceApprovalText(size * sdp)),
        ],
      ),
    ),
  );
}
