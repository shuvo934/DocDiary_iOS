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
      insetPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: MediaQuery.sizeOf(context).height < 500 ? 8 : 24,
      ),
      child: SizedBox(
        width: 560,
        height: MediaQuery.sizeOf(context).height * .74,
        child: ValueListenableBuilder<AttendanceRequestPickerState>(
          valueListenable: widget.state,
          builder: (context, state, _) {
            final rows =
                state.rows.where((r) => r.matches(_search.text)).toList();
            Widget cells(
              List<String> values, {
              bool heading = false,
            }) => IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < values.length; i++)
                    Expanded(
                      flex: const [25, 25, 15, 20, 15][i],
                      child: Container(
                        alignment: Alignment.center,
                        margin: EdgeInsets.only(right: i == 4 ? 0 : 4),
                        color: heading ? DocColors.primary : DocColors.clouds,
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          values[i],
                          textAlign: TextAlign.center,
                          style: attendanceApprovalText(
                            (heading ? 8 : 7) * sdp,
                            family: heading ? 'PatuaOne' : 'OpenSans',
                            weight: heading ? FontWeight.w400 : FontWeight.w700,
                            color: heading ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: DocColors.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'Select Attendance Update Request Code:',
                      style: attendanceApprovalText(
                        12 * sdp,
                        family: 'RussoOne',
                        weight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (state.waiting)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        key: Key('attendance_picker_loading'),
                      ),
                    ),
                  )
                else if (state.failure != null)
                  Expanded(
                    child: Center(
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
                    ),
                  )
                else
                  Expanded(
                    child: CustomScrollView(
                      key: const Key('attendance_picker_rows'),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: 6 * sdp,
                              left: 4 * sdp,
                              right: 4 * sdp,
                              bottom: 2 * sdp,
                            ),
                            child: TextField(
                              key: const Key('attendance_picker_search'),
                              controller: _search,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(() {}),
                              onSubmitted:
                                  (_) => FocusScope.of(context).unfocus(),
                              style: attendanceApprovalText(9 * sdp),
                              autocorrect: false,
                              enableSuggestions: false,
                              smartDashesType: SmartDashesType.disabled,
                              smartQuotesType: SmartQuotesType.disabled,
                              textCapitalization: TextCapitalization.none,
                              decoration: InputDecoration(
                                labelText: 'Search by Request Code or Emp Name',
                                labelStyle: attendanceApprovalText(
                                  9 * sdp,
                                  weight: FontWeight.w400,
                                  color: const Color(0xff6c6e6f),
                                ),
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 14,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8 * sdp),
                                  borderSide: const BorderSide(
                                    color: DocColors.primary,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8 * sdp),
                                  borderSide: const BorderSide(
                                    color: DocColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(5, 8, 5, 0),
                            child: cells(const [
                              'Request Code',
                              'Emp Name',
                              'Emp Code',
                              'Application Date',
                              'Update Date',
                            ], heading: true),
                          ),
                        ),
                        if (rows.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'No Attendance Update Request Found',
                                  textAlign: TextAlign.center,
                                  style: attendanceApprovalText(
                                    11 * sdp,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                if (index.isOdd) {
                                  return const Divider(
                                    height: 1,
                                    color: Colors.black26,
                                  );
                                }
                                final row = rows[index ~/ 2];
                                return InkWell(
                                  key: Key('attendance_request_${row.id}'),
                                  onTap: () => Navigator.pop(context, row),
                                  child: cells(row.cells),
                                );
                              }, childCount: rows.length * 2 - 1),
                            ),
                          ),
                      ],
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
                      child: const Text('CANCEL'),
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
