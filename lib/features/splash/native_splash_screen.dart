import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// MainActivity/activity_main.xml, using the unchanged Android PNG assets.
class NativeSplashScreen extends StatefulWidget {
  const NativeSplashScreen({super.key});

  @override
  State<NativeSplashScreen> createState() => _NativeSplashScreenState();
}

class _NativeSplashScreenState extends State<NativeSplashScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hideSystemBars();
  }

  void _hideSystemBars() {
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _hideSystemBars();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The native project uses Intuit SDP's 300dp reference and 30dp buckets.
    // Use the full viewport, not the inset content width, for resource sizing.
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final resourceWidth =
        shortestSide < 300 ? 300.0 : (shortestSide / 30).floor() * 30.0;
    final logoMargin = 50 * resourceWidth / 300;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFF16A085), Color(0xFF50C2C0)],
          ),
        ),
        child: Padding(
          // drawable/design.xml applies this padding to the RelativeLayout.
          padding: const EdgeInsets.all(7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Android's default ImageView scaleType is FIT_CENTER.
              // Keep the original layer order and transparency.
              Image.asset(
                'assets/images/stylish_backgroud_doc_diary_2.png',
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
              Image.asset(
                'assets/images/stylish_backgroud_doc_diary_1.png',
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: logoMargin),
                  child: Image.asset(
                    'assets/images/doc_diary_logo_shadow.png',
                    width: 1207,
                    fit: BoxFit.contain,
                    semanticLabel: 'DocDiary',
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
