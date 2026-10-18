import 'package:flutter/material.dart';

import 'features/splash/native_splash_screen.dart';

/// Visual inspection only: keeps the splash visible without starting auth/APIs.
/// The normal application entry point remains lib/main.dart.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NativeSplashScreen(),
    ),
  );
}
