import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/features/hr/attendance_update_approval/attendance_approval_models.dart';
import 'package:docdiary_ios/features/hr/attendance_update_approval/native_attendance_request_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'attendance_approval_test_support.dart';

void main() {
  testWidgets(
    'approved search, heading and CANCEL stay fixed while rows scroll',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = ValueNotifier(
        AttendanceRequestPickerState(
          rows: [
            for (var i = 0; i < 50; i++)
              AttendanceApprovalRequest.fromJson(
                approvalRequest(id: '$i', name: 'Employee $i'),
              ),
          ],
        ),
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: docDiaryTheme(),
          home: Scaffold(
            body: NativeAttendanceRequestDialog(state: state, onReload: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final keys = [
        'attendance_picker_search',
        'attendance_picker_table',
        'attendance_picker_cancel',
      ];
      final before = {
        for (final key in keys) key: tester.getRect(find.byKey(Key(key))),
      };
      final search = tester.widget<TextField>(find.byKey(Key(keys.first)));
      expect(search.autocorrect, isFalse);
      expect(search.enableSuggestions, isFalse);
      expect(search.smartDashesType, SmartDashesType.disabled);
      expect(search.smartQuotesType, SmartQuotesType.disabled);
      final list = find.byKey(const Key('attendance_picker_rows'));
      expect(
        tester.widget<ListView>(list).keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
      expect(
        find.byKey(const Key('attendance_picker_compact_scroll')),
        findsNothing,
      );
      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('attendance_request_0')).hitTestable(),
        findsNothing,
      );
      for (final key in keys) {
        expect(tester.getRect(find.byKey(Key(key))), before[key]);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
