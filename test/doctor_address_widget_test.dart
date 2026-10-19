import 'dart:async';

import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/profile/doctor_address_screen.dart';
import 'package:docdiary_ios/features/profile/doctor_address_repository.dart';
import 'package:docdiary_ios/features/profile/doctor_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_support.dart';
import 'support.dart';

void _pauseApp(WidgetTester tester) {
  if (tester.binding.lifecycleState == AppLifecycleState.resumed) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  if (tester.binding.lifecycleState == AppLifecycleState.inactive) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void _resumeApp(WidgetTester tester) {
  if (tester.binding.lifecycleState == AppLifecycleState.paused) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  if (tester.binding.lifecycleState == AppLifecycleState.hidden) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _show(
  WidgetTester tester,
  Harness h, {
  Size size = const Size(393, 852),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  _resumeApp(tester);
  await h.signIn();
  await tester.pumpWidget(
    DocDiaryApp(
      auth: h.auth,
      dashboard: DashboardRepository(h.transport, now: () => h.now),
      initializeOnStart: false,
    ),
  );
  await tester.pumpAndSettle();
  await _tap(tester, 'dashboard_nav_profile');
  await _tap(tester, 'profile_edit_address');
}

Future<void> _finish(WidgetTester tester, Harness h) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

String _text(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
Future<void> _enter(WidgetTester tester, String key, String value) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), value);
  await tester.pumpAndSettle();
}

Future<void> _yes(WidgetTester tester) async {
  await _tap(tester, 'address_update');
  await tester.tap(find.text('Yes'));
  await tester.pumpAndSettle();
}

Iterable<RequestRecord> _writes(Harness h) =>
    h.posts.where((r) => r.uri.path.endsWith('updateAddress'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry
        in {
          'Poppins': [
            'Poppins-Regular.ttf',
            'Poppins-Medium.ttf',
            'Poppins-Bold.ttf',
          ],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
        }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
  });
  testWidgets(
    'native form is seeded, dropdown fills read-only district and No cancels confirmation',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      expect(_text(tester, 'address_street'), 'Example Road');
      expect(_text(tester, 'address_post_office'), 'Savar');
      expect(_text(tester, 'address_thana'), 'Savar');
      expect(_text(tester, 'address_district'), 'Dhaka');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('address_district')))
            .enabled,
        isFalse,
      );
      await _tap(tester, 'address_thana_dropdown');
      expect(find.byKey(const Key('address_thana_options')), findsOneWidget);
      await _tap(tester, 'address_thana_option_21_2');
      expect(_text(tester, 'address_thana'), 'Gazipur Sadar');
      expect(_text(tester, 'address_district'), 'Gazipur');
      await _tap(tester, 'address_update');
      expect(find.text('Update Address!'), findsOneWidget);
      expect(find.text('Do you want to update your address?'), findsOneWidget);
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(_writes(h), isEmpty);
      expect(find.byType(DoctorAddressScreen), findsOneWidget);
      expect(
        h.posts.where((r) => r.uri.path.endsWith('loginLog')),
        hasLength(1),
      );
      await _finish(tester, h);
    },
  );
  testWidgets(
    'multi-word prefix filtering and keyboard resizing keep the dropdown selectable',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      await _enter(tester, 'address_thana', 'Gazipur S');
      expect(
        find.byKey(const Key('address_thana_option_21_0')),
        findsOneWidget,
      );
      expect(find.text('Dhamrai'), findsNothing);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await _tap(tester, 'address_thana_option_21_0');
      expect(_text(tester, 'address_district'), 'Gazipur');
      expect(find.byKey(const Key('address_thana_options')), findsNothing);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await _finish(tester, h);
    },
  );
  testWidgets(
    'Address created after session removal shows recovery without reading stale account data',
    (tester) async {
      final h = profileHarness();
      await h.signIn();
      await h.auth.logout();
      final reads = h.transport.requests.length;
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorAddressScreen(
            auth: h.auth,
            repository: DoctorAddressRepository(h.transport),
            details: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Could Not Get Doctor Data. Please return to Login.'),
        findsOneWidget,
      );
      expect(h.transport.requests.length, reads);
      await _finish(tester, h);
      h.auth.dispose();
    },
  );
  testWidgets(
    'validation and edited invalid Thana cannot reuse a previous id or district',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      await _enter(tester, 'address_street', '');
      await _tap(tester, 'address_update');
      expect(find.text('Please Provide Street Address/Village'), findsWidgets);
      await _enter(tester, 'address_street', 'New Road');
      await _enter(tester, 'address_post_office', '');
      await _tap(tester, 'address_update');
      expect(find.text('Please Provide Post Office'), findsWidgets);
      await _enter(tester, 'address_post_office', 'New Post Office');
      await _enter(tester, 'address_thana', 'Imaginary place');
      expect(_text(tester, 'address_district'), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Invalid Thana/Upazila'), findsOneWidget);
      await _tap(tester, 'address_update');
      expect(find.text('Update Address!'), findsNothing);
      expect(_writes(h), isEmpty);
      await _enter(tester, 'address_thana', 'Gazipur Sadar');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_text(tester, 'address_district'), 'Gazipur');
      await _finish(tester, h);
    },
  );
  testWidgets(
    'confirmed save sends native headers then Ok returns to freshly loaded Profile',
    (tester) async {
      final h = profileHarness();
      JsonMap saved = profileDetails();
      final get = h.transport.onGet!;
      h.transport.onGet =
          (uri) async =>
              uri.path.endsWith('getDocProfile')
                  ? {
                    'count': 1,
                    'items': [saved],
                  }
                  : await get(uri);
      await _show(tester, h);
      h.transport.onPost = (uri, headers) async {
        expect(uri.path, endsWith('/doc_profile/updateAddress'));
        saved = {
          ...saved,
          'doc_village': headers['P_S_ADDRESS'],
          'doc_poffice': headers['P_POST_OFFICE'],
          'doc_dd_id': headers['P_DD_ID'],
          'dist_id': '2',
          'dd_thana_name': 'Gazipur Sadar',
          'dist_name': 'Gazipur',
        };
        return {'string_out': 'Successfully Created'};
      };
      await _enter(tester, 'address_street', 'New Road 25');
      await _enter(tester, 'address_post_office', 'Gazipur');
      await _tap(tester, 'address_thana_dropdown');
      await _tap(tester, 'address_thana_option_21_2');
      await _yes(tester);
      expect(find.text('Success!'), findsOneWidget);
      expect(find.text('Address Updated Successfully.'), findsOneWidget);
      expect(_writes(h).single.headers, {
        'P_S_ADDRESS': 'New Road 25',
        'P_POST_OFFICE': 'Gazipur',
        'P_DD_ID': '21',
        'P_DOC_ID': '10',
      });
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.text('Success!'), findsOneWidget);
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      expect(find.byType(DoctorAddressScreen), findsNothing);
      expect(find.byType(DoctorProfileScreen), findsOneWidget);
      expect(find.text('New Road 25'), findsOneWidget);
      expect(find.text('doctor@example.invalid'), findsOneWidget);
      expect(_writes(h), hasLength(1));
      expect(
        h.posts.where((r) => r.uri.path.endsWith('loginLog')),
        hasLength(1),
      );
      await _finish(tester, h);
    },
  );
  testWidgets(
    'Close discards unsaved edits and leaves the saved address unchanged',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      await _enter(tester, 'address_street', 'Unsaved Road');
      await _tap(tester, 'address_close');
      expect(find.byType(DoctorAddressScreen), findsNothing);
      expect(find.text('Example Road'), findsOneWidget);
      expect(find.text('Unsaved Road'), findsNothing);
      expect(_writes(h), isEmpty);
      await _finish(tester, h);
    },
  );
  testWidgets(
    'directory Error Retry is non-dismissible and preserves the seeded address',
    (tester) async {
      final h = profileHarness();
      final get = h.transport.onGet!;
      var attempts = 0;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocThana') && attempts++ == 0) {
          throw const AppFailure('Directory interrupted');
        }
        return await get(uri);
      };
      await _show(tester, h);
      expect(find.byKey(const Key('address_load_error')), findsOneWidget);
      await tester.tapAt(const Offset(2, 2));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('address_load_error')), findsOneWidget);
      await _tap(tester, 'address_load_retry');
      expect(attempts, 2);
      expect(_text(tester, 'address_street'), 'Example Road');
      expect(_writes(h), isEmpty);
      await _finish(tester, h);
    },
  );
  testWidgets('directory Error Exit returns to Profile without a write', (
    tester,
  ) async {
    final h = profileHarness();
    final get = h.transport.onGet!;
    h.transport.onGet =
        (uri) async =>
            uri.path.endsWith('getDocThana')
                ? throw const AppFailure('Directory interrupted')
                : await get(uri);
    await _show(tester, h);
    await _tap(tester, 'address_load_exit');
    expect(find.byType(DoctorAddressScreen), findsNothing);
    expect(find.text('Example Road'), findsOneWidget);
    expect(_writes(h), isEmpty);
    await _finish(tester, h);
  });
  testWidgets(
    'save error waits for explicit Retry and reuses the confirmed values once',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      var attempts = 0;
      h.transport.onPost =
          (_, _) async =>
              ++attempts == 1
                  ? {'string_out': 'Address not accepted'}
                  : {'string_out': 'Successfully Created'};
      await _enter(tester, 'address_street', 'Retry Road');
      await _yes(tester);
      expect(find.byKey(const Key('address_save_error')), findsOneWidget);
      expect(find.textContaining('Address not accepted'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(attempts, 1);
      await _tap(tester, 'address_save_retry');
      expect(attempts, 2);
      expect(
        _writes(h).every((r) => r.headers['P_S_ADDRESS'] == 'Retry Road'),
        isTrue,
      );
      expect(find.text('Success!'), findsOneWidget);
      await _finish(tester, h);
    },
  );
  testWidgets('save Error Cancel keeps typed fields and never claims success', (
    tester,
  ) async {
    final h = profileHarness();
    await _show(tester, h);
    h.transport.onPost =
        (_, _) async => throw const AppFailure('Save interrupted');
    await _enter(tester, 'address_street', 'Keep Road');
    await _yes(tester);
    await _tap(tester, 'address_save_cancel');
    expect(_text(tester, 'address_street'), 'Keep Road');
    expect(_writes(h), hasLength(1));
    expect(find.text('Success!'), findsNothing);
    await _finish(tester, h);
  });
  testWidgets(
    'empty directory shows native helper and duplicate names retain the selected identity',
    (tester) async {
      final empty = profileHarness();
      final get = empty.transport.onGet!;
      empty.transport.onGet =
          (uri) async =>
              uri.path.endsWith('getDocThana')
                  ? {'count': 0, 'items': null}
                  : await get(uri);
      await _show(tester, empty);
      expect(find.text('No Thana/Upazila Found'), findsOneWidget);
      await _tap(tester, 'address_thana_dropdown');
      expect(find.byKey(const Key('address_thana_options')), findsNothing);
      await _finish(tester, empty);
      final h = profileHarness();
      final base = h.transport.onGet!;
      h.transport.onGet =
          (uri) async =>
              uri.path.endsWith('getDocThana')
                  ? {
                    'count': 2,
                    'items': [
                      {
                        'dd_id': '1',
                        'dd_dist_id': '1',
                        'dd_thana_name': 'Sadar',
                        'dist_name': 'First',
                      },
                      {
                        'dd_id': '2',
                        'dd_dist_id': '2',
                        'dd_thana_name': 'Sadar',
                        'dist_name': 'Last',
                      },
                    ],
                  }
                  : await base(uri);
      await _show(tester, h);
      await _tap(tester, 'address_thana_dropdown');
      expect(find.text('Sadar (First)'), findsOneWidget);
      expect(find.text('Sadar (Last)'), findsOneWidget);
      await _tap(tester, 'address_thana_option_1_0');
      expect(_text(tester, 'address_district'), 'First');
      await _yes(tester);
      expect(_writes(h).single.headers['P_DD_ID'], '1');
      await _finish(tester, h);
    },
  );
  testWidgets(
    'small screens and large text retain scroll, dropdown and update access without overflow',
    (tester) async {
      for (final size in [const Size(320, 640), const Size(393, 852)]) {
        final h = profileHarness();
        await _show(tester, h, size: size, scale: 2);
        await _tap(tester, 'address_thana_dropdown');
        expect(find.byKey(const Key('address_thana_options')), findsOneWidget);
        await _tap(tester, 'address_thana_option_21_2');
        await _tap(tester, 'address_update');
        expect(find.text('Update Address!'), findsOneWidget);
        await tester.tap(find.text('No'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _finish(tester, h);
      }
    },
  );
  testWidgets(
    'fresh access denial before save closes old Profile routes and prevents POST',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      h.doctorData['access_flag'] = '0';
      await _yes(tester);
      expect(h.auth.stage, AuthStage.accountBlocked);
      expect(find.byType(DoctorAddressScreen), findsNothing);
      expect(_writes(h), isEmpty);
      await _finish(tester, h);
    },
  );
  testWidgets(
    'forced logout immediately before dispatch prevents the address write',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      final get = h.transport.onGet!;
      h.transport.onGet =
          (uri) async =>
              uri.path.endsWith('getDocFLFlag')
                  ? {
                    'items': [
                      {'fl_flag': '1'},
                    ],
                  }
                  : await get(uri);
      await _yes(tester);
      expect(h.auth.stage, AuthStage.accountBlocked);
      expect(find.byType(DoctorAddressScreen), findsNothing);
      expect(_writes(h), isEmpty);
      await _finish(tester, h);
    },
  );
  testWidgets(
    'paused stale directory result is ignored and resume preserves edited fields',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      await _enter(tester, 'address_street', 'Keep Across Resume');
      final pending = Completer<JsonMap>();
      final get = h.transport.onGet!;
      var reads = 0;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocThana') && ++reads == 1) {
          return await pending.future;
        }
        return await get(uri);
      };
      _pauseApp(tester);
      _resumeApp(tester);
      await tester.pump();
      _pauseApp(tester);
      pending.complete({'count': 0, 'items': null});
      await tester.pump();
      _resumeApp(tester);
      await tester.pumpAndSettle();
      expect(_text(tester, 'address_street'), 'Keep Across Resume');
      expect(find.text('No Thana/Upazila Found'), findsNothing);
      expect(_writes(h), isEmpty);
      await _finish(tester, h);
    },
  );
  testWidgets(
    'background save success is acknowledged on resume with exactly one POST',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      final pending = Completer<JsonMap>();
      h.transport.onPost = (_, _) async => await pending.future;
      await _tap(tester, 'address_update');
      await tester.tap(find.text('Yes'));
      await tester.pump();
      expect(_writes(h), hasLength(1));
      _pauseApp(tester);
      pending.complete({'string_out': 'Successfully Created'});
      await tester.pump();
      expect(find.text('Success!'), findsNothing);
      _resumeApp(tester);
      await tester.pumpAndSettle();
      expect(find.text('Success!'), findsOneWidget);
      expect(_writes(h), hasLength(1));
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      expect(find.byType(DoctorAddressScreen), findsNothing);
      await _finish(tester, h);
    },
  );
  testWidgets(
    'Retry after a background success only rechecks access and never resends the save',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      final pending = Completer<JsonMap>();
      h.transport.onPost = (_, _) async => await pending.future;
      await _tap(tester, 'address_update');
      await tester.tap(find.text('Yes'));
      await tester.pump();
      _pauseApp(tester);
      final get = h.transport.onGet!;
      var failed = false;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocData') && !failed) {
          failed = true;
          throw const AppFailure('Resume access check interrupted');
        }
        return await get(uri);
      };
      pending.complete({'string_out': 'Successfully Created'});
      await tester.pump();
      _resumeApp(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('address_save_error')), findsOneWidget);
      await _tap(tester, 'address_save_retry');
      expect(find.text('Success!'), findsOneWidget);
      expect(_writes(h), hasLength(1));
      await _finish(tester, h);
    },
  );
  testWidgets(
    'pause during preflight prevents POST and Cancel cannot trigger an automatic save',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      final get = h.transport.onGet!;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocFLFlag')) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        }
        return await get(uri);
      };
      await _tap(tester, 'address_update');
      await tester.tap(find.text('Yes'));
      await tester.pump();
      expect(_writes(h), isEmpty);
      _resumeApp(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('address_save_error')), findsOneWidget);
      await _tap(tester, 'address_save_cancel');
      expect(_writes(h), isEmpty);
      expect(_text(tester, 'address_street'), 'Example Road');
      await _finish(tester, h);
    },
  );
  testWidgets(
    'logout during a pending save cannot show a stale success over Login',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      final pending = Completer<JsonMap>();
      h.transport.onPost = (_, _) async => await pending.future;
      await _tap(tester, 'address_update');
      await tester.tap(find.text('Yes'));
      await tester.pump();
      await h.auth.logout();
      await tester.pumpAndSettle();
      pending.complete({'string_out': 'Successfully Created'});
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DoctorAddressScreen), findsNothing);
      expect(find.text('Success!'), findsNothing);
      expect(_writes(h), hasLength(1));
      await _finish(tester, h);
    },
  );
}
