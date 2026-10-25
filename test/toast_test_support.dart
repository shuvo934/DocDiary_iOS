import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the real fluttertoast channel instead of drawing a fake SnackBar.
class ToastRecorder {
  static const channel = MethodChannel('PonnamKarthik/fluttertoast');
  final calls = <MethodCall>[];
  String? currentMessage;
  Future<Object?> Function(MethodCall)? intercept;

  List<String> get messages => [
    for (final call in calls)
      if (call.method == 'showToast')
        (call.arguments as Map<Object?, Object?>)['msg']! as String,
  ];

  void install() {
    calls.clear();
    currentMessage = null;
    intercept = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          final handler = intercept;
          final result = handler == null ? true : await handler(call);
          if (result == true) {
            if (call.method == 'cancel') {
              currentMessage = null;
            } else if (call.method == 'showToast') {
              currentMessage =
                  (call.arguments as Map<Object?, Object?>)['msg']! as String;
            }
          }
          return result;
        });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }
}
