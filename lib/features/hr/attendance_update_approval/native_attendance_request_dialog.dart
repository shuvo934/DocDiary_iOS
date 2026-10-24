import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import 'attendance_approval_models.dart';
import 'native_attendance_approval_layout.dart';

class AttendanceRequestPickerState {
  const AttendanceRequestPickerState({
    this.rows = const [],
    this.waiting = false,
    this.failure,
  });
  final List<AttendanceApprovalRequest> rows;
  final bool waiting;
  final Object? failure;
}

class NativeAttendanceRequestDialog extends StatefulWidget {
  const NativeAttendanceRequestDialog({
    super.key,
    required this.state,
    required this.onReload,
  });
  final ValueNotifier<AttendanceRequestPickerState> state;
  final VoidCallback onReload;
  @override
  State<NativeAttendanceRequestDialog> createState() =>
      _NativeAttendanceRequestDialogState();
}

class _NativeAttendanceRequestDialogState
    extends State<NativeAttendanceRequestDialog> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sdp = attendanceApprovalScale(context);
    return Dialog(
      key: const Key('attendance_request_picker'),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: MediaQuery.sizeOf(context).height < 500 ? 8 : 24,
      ),
      child: SizedBox(
        width: 560,
        // Match native wrap_content: short lists do not reserve a fixed
        // percentage of the screen. Flexible + shrinkWrap cap long lists.
        child: ValueListenableBuilder<AttendanceRequestPickerState>(
          valueListenable: widget.state,
          builder: (context, state, _) {
            final rows =
                state.rows.where((r) => r.matches(_search.text)).toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: DocColors.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'Select Attendance Update Request Code:',
                      style: attendanceApprovalText(
                        13 * sdp,
                        family: 'RussoOne',
                        weight: FontWeight.w400,
                        color: Colors.white,
                      ).copyWith(height: 1.1),
                    ),
                  ),
                ),
                if (state.waiting)
                  Flexible(
                    child: SizedBox(
                      height: 96 * sdp,
                      child: const Center(
                        child: CircularProgressIndicator(
                          key: Key('attendance_picker_loading'),
                        ),
                      ),
                    ),
                  )
                else if (state.failure != null)
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dashboardFailureDetail(state.failure!),
                            textAlign: TextAlign.center,
                            style: attendanceApprovalText(
                              10 * sdp,
                              weight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            key: const Key('attendance_picker_retry'),
                            onPressed: widget.onReload,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: _AdaptivePinnedRequestBody(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ───── Fixed: Search field ─────
                          Padding(
                            padding: EdgeInsets.only(
                              top: 6 * sdp,
                              left: 4 * sdp,
                              right: 4 * sdp,
                              bottom: 2 * sdp,
                            ),
                            child: Material(
                              elevation: 1,
                              borderRadius: BorderRadius.circular(8 * sdp),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8 * sdp),
                                  border: Border.all(color: DocColors.primary),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(1),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      8 * sdp,
                                    ),
                                    child: TextField(
                                      key: const Key(
                                        'attendance_picker_search',
                                      ),
                                      controller: _search,
                                      textInputAction: TextInputAction.done,
                                      onChanged: (_) => setState(() {}),
                                      onSubmitted:
                                          (_) =>
                                              FocusScope.of(context).unfocus(),
                                      style: attendanceApprovalText(
                                        10 * sdp,
                                        color: const Color(0xff6c6e6f),
                                      ),
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      smartDashesType: SmartDashesType.disabled,
                                      smartQuotesType: SmartQuotesType.disabled,
                                      textCapitalization:
                                          TextCapitalization.none,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Search by Request Code or Emp Name',
                                        labelStyle: attendanceApprovalText(
                                          10 * sdp,
                                          color: const Color(0xffb0bec5),
                                        ),
                                        floatingLabelStyle:
                                            attendanceApprovalText(
                                              8 * sdp,
                                              color: DocColors.primary,
                                            ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 11 * sdp,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ───── Fixed: Table header ─────
                          Padding(
                            key: const Key('attendance_picker_table'),
                            padding: const EdgeInsets.fromLTRB(5, 8, 5, 0),
                            child: Material(
                              color: Colors.white,
                              elevation: 2,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(10 * sdp),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(10 * sdp),
                                ),
                                child: _RequestCells(
                                  values: const [
                                    'Request Code',
                                    'Emp Name',
                                    'Emp Code',
                                    'Application Date',
                                    'Update Date',
                                  ],
                                  heading: true,
                                  sdp: sdp,
                                ),
                              ),
                            ),
                          ),

                          // ───── Scrollable: শুধু rows ─────
                          if (rows.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4 * sdp,
                                vertical: 8 * sdp,
                              ),
                              child: Text(
                                'No Attendance Update Request Found',
                                textAlign: TextAlign.center,
                                style: attendanceApprovalText(
                                  11 * sdp,
                                  weight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            )
                          else
                            Flexible(
                              child: ListView.separated(
                                key: const Key('attendance_picker_rows'),
                                shrinkWrap: true,
                                padding: const EdgeInsets.fromLTRB(5, 0, 5, 7),
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: rows.length,
                                separatorBuilder:
                                    (_, __) => const Divider(
                                      height: 1,
                                      color: Colors.black26,
                                    ),
                                itemBuilder: (context, i) {
                                  final row = rows[i];
                                  final radius =
                                      i == rows.length - 1
                                          ? BorderRadius.vertical(
                                            bottom: Radius.circular(10 * sdp),
                                          )
                                          : BorderRadius.zero;
                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 2 * sdp,
                                    ),
                                    child: Material(
                                      color: Colors.white,
                                      elevation: 2,
                                      borderRadius: radius,
                                      child: InkWell(
                                        key: Key(
                                          'attendance_request_${row.id}',
                                        ),
                                        onTap:
                                            () => Navigator.pop(context, row),
                                        child: ClipRRect(
                                          borderRadius: radius,
                                          child: _RequestCells(
                                            values: row.cells,
                                            sdp: sdp,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('attendance_picker_cancel'),
                      onPressed:
                          state.waiting ? null : () => Navigator.pop(context),
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: DocColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RequestCells extends StatelessWidget {
  const _RequestCells({
    required this.values,
    required this.sdp,
    this.heading = false,
  });
  final List<String> values;
  final double sdp;
  final bool heading;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            flex: const [25, 25, 15, 20, 15][i],
            child: Container(
              alignment: Alignment.center,
              margin: EdgeInsets.only(
                left: i == 0 ? 0 : 2,
                right: i == 4 ? 0 : 2,
              ),
              color: heading ? DocColors.primary : DocColors.clouds,
              padding: const EdgeInsets.all(4),
              child: Text(
                values[i],
                textAlign: TextAlign.center,
                style: attendanceApprovalText(
                  (heading ? 9 : 8) * sdp,
                  family: heading ? 'PatuaOne' : 'OpenSans',
                  weight: heading ? FontWeight.w400 : FontWeight.w700,
                  color: heading ? Colors.white : Colors.black87,
                ).copyWith(height: 1.35),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Preserve fixed search/headings and row-only scrolling on regular screens.
/// A short viewport still exposes every row without shrinking the user's fonts.
class _AdaptivePinnedRequestBody extends StatelessWidget {
  const _AdaptivePinnedRequestBody({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
      final minimum = 170 * attendanceApprovalScale(context) * scale;
      if (bounds.maxHeight >= minimum) return child;
      return SingleChildScrollView(
        key: const Key('attendance_picker_compact_scroll'),
        child: SizedBox(height: minimum, child: child),
      );
    },
  );
}
