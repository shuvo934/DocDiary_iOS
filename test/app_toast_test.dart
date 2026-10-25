import 'dart:async';
import 'package:docdiary_ios/core/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'toast_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = ToastRecorder();
  setUp(native.install);
  tearDown(native.uninstall);

  Future<BuildContext> host(WidgetTester t, {bool observe = true}) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    late BuildContext root;
    await t.pumpWidget(
      MaterialApp(
        navigatorObservers: [if (observe) AppToastNavigationObserver()],
        home: Builder(
          builder: (context) {
            root = context;
            return const Scaffold(body: Text('Root'));
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    return root;
  }

  Future<void> finish(WidgetTester t, List<AppToastOwner> owners) async {
    for (final owner in owners) {
      owner.dispose();
    }
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  testWidgets(
    'native channel receives unchanged Unicode and consistent iOS style',
    (t) async {
      final context = await host(t), owner = AppToastOwner();
      owner.show(context, 'বাংলা নোট 🙂 "quoted"\nDone');
      await t.pumpAndSettle();
      expect(native.calls.map((c) => c.method), ['cancel', 'showToast']);
      final args = native.calls.last.arguments! as Map<Object?, Object?>;
      expect(args['msg'], 'বাংলা নোট 🙂 "quoted"\nDone');
      expect(args['length'], 'short');
      expect(args['time'], 2);
      expect(args['gravity'], 'bottom');
      expect(args['iosBgcolor'], 0xcc000000);
      expect(args['iosTextcolor'], 0xffffffff);
      expect(args['fontSize'], 14);
      expect(find.byType(SnackBar), findsNothing);
      await finish(t, [owner]);
    },
  );
  testWidgets('empty messages do not cancel or replace a useful notice', (
    t,
  ) async {
    final context = await host(t), owner = AppToastOwner();
    owner.show(context, 'Keep this');
    await t.pumpAndSettle();
    owner.show(context, ' \n ');
    await t.pumpAndSettle();
    expect(native.messages, ['Keep this']);
    expect(native.currentMessage, 'Keep this');
    await finish(t, [owner]);
  });
  testWidgets('rapid feedback uses the latest message without a stale queue', (
    t,
  ) async {
    final context = await host(t), owner = AppToastOwner();
    owner.show(context, 'First');
    owner.show(context, 'Second');
    owner.show(context, 'Latest');
    await t.pumpAndSettle();
    expect(native.messages, ['Latest']);
    await finish(t, [owner]);
  });
  testWidgets('disposing an older screen cannot cancel a newer screen notice', (
    t,
  ) async {
    final context = await host(t),
        older = AppToastOwner(),
        newer = AppToastOwner();
    older.show(context, 'Old screen');
    await t.pumpAndSettle();
    newer.show(context, 'New screen');
    await t.pumpAndSettle();
    older.dispose();
    await t.pumpAndSettle();
    expect(native.currentMessage, 'New screen');
    newer.dispose();
    await t.pumpAndSettle();
    expect(native.currentMessage, isNull);
    await finish(t, [older, newer]);
  });
  testWidgets(
    'disposed owners ignore late callbacks and can be disposed twice',
    (t) async {
      final context = await host(t), owner = AppToastOwner();
      owner.dispose();
      owner.dispose();
      owner.show(context, 'Late success');
      await t.pumpAndSettle();
      expect(native.messages, isEmpty);
      await finish(t, [owner]);
    },
  );
  for (final state in [AppLifecycleState.inactive, AppLifecycleState.paused]) {
    testWidgets(
      '$state cancels visible feedback and resume does not replay it',
      (t) async {
        final context = await host(t), owner = AppToastOwner();
        owner.show(context, 'Shown');
        await t.pumpAndSettle();
        t.binding.handleAppLifecycleStateChanged(state);
        await t.pumpAndSettle();
        expect(native.currentMessage, isNull);
        owner.show(context, 'Background result');
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        expect(native.messages, ['Shown']);
        owner.show(context, 'Fresh result');
        await t.pumpAndSettle();
        expect(native.messages.last, 'Fresh result');
        await finish(t, [owner]);
      },
    );
  }
  testWidgets('background before dispatch drops the queued notice', (t) async {
    final context = await host(t), owner = AppToastOwner();
    owner.show(context, 'Queued');
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pumpAndSettle();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(native.messages, isEmpty);
    await finish(t, [owner]);
  });
  testWidgets(
    'dispose during delayed native cancel cannot show stale feedback',
    (t) async {
      final context = await host(t), owner = AppToastOwner();
      final gate = Completer<Object?>();
      native.intercept =
          (call) =>
              call.method == 'cancel'
                  ? gate.future
                  : Future<Object?>.value(true);
      owner.show(context, 'Queued');
      await t.pump();
      expect(native.calls.single.method, 'cancel');
      owner.dispose();
      native.intercept = null;
      gate.complete(true);
      await t.pumpAndSettle();
      expect(native.messages, isEmpty);
      await finish(t, [owner]);
    },
  );
  testWidgets(
    'route identity drops a pending notice even without an observer',
    (t) async {
      final context = await host(t, observe: false), owner = AppToastOwner();
      final gate = Completer<Object?>();
      native.intercept =
          (call) =>
              call.method == 'cancel'
                  ? gate.future
                  : Future<Object?>.value(true);
      owner.show(context, 'Old route');
      await t.pump();
      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Next'))),
        ),
      );
      await t.pumpAndSettle();
      native.intercept = null;
      gate.complete(true);
      await t.pumpAndSettle();
      expect(native.messages, isEmpty);
      await finish(t, [owner]);
    },
  );
  testWidgets(
    'navigation clears a visible toast and returning does not replay it',
    (t) async {
      final context = await host(t), owner = AppToastOwner();
      owner.show(context, 'Parent notice');
      await t.pumpAndSettle();
      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Next'))),
        ),
      );
      await t.pumpAndSettle();
      expect(native.currentMessage, isNull);
      owner.show(context, 'Hidden parent');
      await t.pumpAndSettle();
      Navigator.of(t.element(find.text('Next'))).pop();
      await t.pumpAndSettle();
      expect(native.messages, ['Parent notice']);
      await finish(t, [owner]);
    },
  );
  for (final operation in ['replace', 'remove']) {
    testWidgets('route $operation clears window-level toast feedback', (
      t,
    ) async {
      final context = await host(t), owner = AppToastOwner();
      final route = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Next')),
      );
      unawaited(Navigator.of(context).push<void>(route));
      await t.pumpAndSettle();
      final next = t.element(find.text('Next'));
      owner.show(next, 'Next notice');
      await t.pumpAndSettle();
      if (operation == 'replace') {
        Navigator.of(next).replace(
          oldRoute: route,
          newRoute: MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Replacement')),
          ),
        );
      } else {
        Navigator.of(next).removeRoute(route);
      }
      await t.pumpAndSettle();
      expect(native.currentMessage, isNull);
      await finish(t, [owner]);
    });
  }
  for (final method in ['cancel', 'showToast']) {
    testWidgets(
      '$method platform failure does not escape or break later feedback',
      (t) async {
        final context = await host(t), owner = AppToastOwner();
        native.intercept = (call) async {
          if (call.method == method) {
            throw PlatformException(code: 'test_failure');
          }
          return true;
        };
        owner.show(context, 'Failed feedback');
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        native.intercept = null;
        owner.show(context, 'Recovered');
        await t.pumpAndSettle();
        expect(native.currentMessage, 'Recovered');
        await finish(t, [owner]);
      },
    );
  }
  testWidgets(
    'missing native plugin cannot turn a completed action into an error',
    (t) async {
      final context = await host(t), owner = AppToastOwner();
      native.intercept = (_) async => throw MissingPluginException();
      owner.show(context, 'Saved');
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      native.intercept = null;
      owner.show(context, 'Ready');
      await t.pumpAndSettle();
      expect(native.currentMessage, 'Ready');
      await finish(t, [owner]);
    },
  );
}
