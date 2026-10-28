import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_rx_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_review_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dynamic_review_test_support.dart';

Future<void> _host(
  WidgetTester tester,
  DynamicReviewDraftFixture f, {
  required ValueChanged<int> onEdit,
  Size size = const Size(393, 600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: docDiaryTheme(),
      home: Scaffold(
        body: NativeDynamicReviewTab(review: f.review, onEdit: onEdit),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late DynamicReviewDraftFixture f;
  setUp(() => f = DynamicReviewDraftFixture());
  tearDown(() => f.dispose());

  testWidgets('empty native Review and all three edit shortcuts', (
    tester,
  ) async {
    final edited = <int>[];
    await _host(tester, f, onEdit: edited.add);
    expect(find.text('Rx information required'), findsOneWidget);
    expect(find.text('No information added'), findsNWidgets(3));
    expect(find.text('0 item'), findsNWidgets(3));
    for (final section in ['clinical', 'rx', 'advice']) {
      final target = find.byKey(Key('dy_review_edit_$section'));
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }
    expect(edited, [0, 1, 2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Review reacts to real drafts and medicine permission without losing entries',
    (tester) async {
      await _host(tester, f, onEdit: (_) {});
      f.populate();
      await tester.pumpAndSettle();
      expect(find.text('Ready for final review'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('dy_review_count_clinical')))
            .data,
        '4 items',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('dy_review_count_rx'))).data,
        '3 items',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('dy_review_count_advice')))
            .data,
        '5 items',
      );
      f.rx.deleteTherapy(f.rx.therapies.single.localId);
      f.rx.deleteTreatmentPlan(f.rx.treatmentPlans.single.localId);
      f.review.medicineAllowed = false;
      await tester.pumpAndSettle();
      expect(find.text('Rx information required'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('dy_review_count_rx'))).data,
        '0 item',
      );
      expect(f.rx.medicines, hasLength(1));
      f.rx.saveTreatmentPlan(DynamicTreatmentPlanEntry(text: 'Plan only'));
      await tester.pumpAndSettle();
      expect(find.text('Ready for final review'), findsOneWidget);
    },
  );

  testWidgets('small viewport scroll remains in place when a summary changes', (
    tester,
  ) async {
    f.populate();
    await _host(tester, f, size: const Size(320, 380), onEdit: (_) {});
    final scroll =
        tester
            .widget<SingleChildScrollView>(
              find.byKey(const PageStorageKey<String>('dynamic_review_scroll')),
            )
            .controller!;
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final offset = scroll.offset;
    f.rx.saveTreatmentPlan(DynamicTreatmentPlanEntry(text: 'Second plan'));
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(offset, .1));
    expect(
      find.byKey(const Key('dy_review_edit_advice')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
