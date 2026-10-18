import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';

const _loginSystemBars = SystemUiOverlayStyle(
  statusBarColor: DocColors.primary,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.white,
  systemNavigationBarIconBrightness: Brightness.dark,
);

double _sdp(BuildContext context) {
  final width = MediaQuery.sizeOf(context).shortestSide;
  return width < 300 ? 1 : (width / 30).floor() * 30 / 300;
}

/// The layout and drawable values come from activity_doc_login.xml.
class NativeLoginLayout extends StatelessWidget {
  const NativeLoginLayout({
    super.key,
    required this.mobile,
    required this.password,
    required this.remember,
    required this.hidePassword,
    required this.onRememberChanged,
    required this.onTogglePassword,
    required this.onDone,
    required this.onSubmit,
    required this.onContact,
  });

  final TextEditingController mobile;
  final TextEditingController password;
  final bool remember;
  final bool hidePassword;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onDone;
  final VoidCallback onSubmit;
  final VoidCallback onContact;

  TextStyle _text(
    String family,
    double size, {
    Color color = Colors.black,
    FontWeight weight = FontWeight.normal,
  }) => TextStyle(
    inherit: false,
    textBaseline: TextBaseline.alphabetic,
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    color: color,
  );

  InputDecoration _input(String hint, double sdp, {Widget? suffix}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: _text(
        'Ubuntu',
        16,
        color: const Color(0x99000000),
        weight: FontWeight.w500,
      ),
      filled: true,
      fillColor: DocColors.clouds,
      isDense: true,
      contentPadding: EdgeInsets.fromLTRB(
        20 * sdp,
        13 * sdp,
        20 * sdp,
        15 * sdp,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      disabledBorder: border,
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sdp = _sdp(context);
    final media = MediaQuery.of(context);
    final bottomInset = math.max(
      media.viewPadding.bottom,
      media.viewInsets.bottom,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _loginSystemBars,
      child: Scaffold(
        backgroundColor: DocColors.primary,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: ColoredBox(
            color: Colors.white,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    SizedBox(
                      key: const Key('native_login_header'),
                      height: constraints.maxHeight * .35,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/docdiary_login_fron_view_new.png',
                            fit: BoxFit.fill,
                            excludeFromSemantics: true,
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40 * sdp),
                            child: Center(
                              // Center the native 140sdp box including its 8/60sdp margins.
                              child: Transform.translate(
                                offset: Offset(0, (8 - 60) * sdp / 2),
                                child: Image.asset(
                                  'assets/images/doc_diary_logo_shadow.png',
                                  width: 140 * sdp,
                                  height: 140 * sdp,
                                  fit: BoxFit.contain,
                                  semanticLabel: 'DocDiary',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        // Keep the header in place; only the form avoids the keyboard.
                        padding: EdgeInsets.only(bottom: bottomInset),
                        child: SingleChildScrollView(
                          key: const Key('native_login_scroll'),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.all(2),
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    15,
                                    20,
                                    10,
                                  ),
                                  child: Text(
                                    'WELCOME!',
                                    textAlign: TextAlign.center,
                                    style: _text(
                                      'Poppins',
                                      22 * sdp,
                                      color: DocColors.greenSea,
                                      weight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    10,
                                  ),
                                  child: Text(
                                    'Login to continue',
                                    textAlign: TextAlign.center,
                                    style: _text(
                                      'PatuaOne',
                                      12 * sdp,
                                      color: Colors.black54,
                                      weight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    15,
                                    20,
                                    0,
                                  ),
                                  child: TextField(
                                    key: const Key('mobile_field'),
                                    controller: mobile,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    style: _text(
                                      'Ubuntu',
                                      16,
                                      weight: FontWeight.w500,
                                    ),
                                    cursorColor: DocColors.primary,
                                    decoration: _input('Mobile No', sdp),
                                    onSubmitted: (_) => onDone(),
                                    onTapOutside: (_) => onDone(),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    10,
                                    20,
                                    10,
                                  ),
                                  child: TextField(
                                    key: const Key('password_field'),
                                    controller: password,
                                    obscureText: hidePassword,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    style: _text(
                                      'Ubuntu',
                                      16,
                                      weight: FontWeight.w500,
                                    ),
                                    cursorColor: DocColors.primary,
                                    onSubmitted: (_) => onDone(),
                                    onTapOutside: (_) => onDone(),
                                    decoration: _input(
                                      'Password',
                                      sdp,
                                      suffix: IconButton(
                                        tooltip:
                                            hidePassword
                                                ? 'Show password'
                                                : 'Hide password',
                                        onPressed: onTogglePassword,
                                        icon: Icon(
                                          hidePassword
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: DocColors.muted,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 20),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: InkWell(
                                      key: const Key('remember_me'),
                                      onTap: () => onRememberChanged(!remember),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 32,
                                            height: 48,
                                            child: Checkbox(
                                              value: remember,
                                              activeColor: DocColors.greenSea,
                                              checkColor: Colors.white,
                                              side: const BorderSide(
                                                color: DocColors.greenSea,
                                                width: 2,
                                              ),
                                              onChanged:
                                                  (value) => onRememberChanged(
                                                    value ?? false,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Remember Me',
                                            style: _text(
                                              'OpenSans',
                                              14,
                                              color: DocColors.muted,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    30,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    elevation: 2,
                                    borderRadius: BorderRadius.circular(10),
                                    clipBehavior: Clip.antiAlias,
                                    child: Ink(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            DocColors.primary,
                                            DocColors.greenSea,
                                          ],
                                        ),
                                      ),
                                      child: InkWell(
                                        key: const Key('login_button'),
                                        onTap: onSubmit,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minHeight: 48,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(7),
                                            child: Center(
                                              child: Text(
                                                'LOGIN',
                                                style: _text(
                                                  'Poppins',
                                                  14 * sdp,
                                                  color: Colors.white,
                                                  weight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  "Don't have an account?",
                                  textAlign: TextAlign.center,
                                  style: _text(
                                    'Poppins',
                                    10 * sdp,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                                InkWell(
                                  key: const Key('contact_here'),
                                  onTap: onContact,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: 5,
                                      bottom: 15,
                                    ),
                                    child: Text(
                                      'Contact Here',
                                      textAlign: TextAlign.center,
                                      style: _text(
                                        'Poppins',
                                        11 * sdp,
                                        color: DocColors.primary,
                                        weight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}

/// DocLogin hides the form and shows a central indicator while logging in.
class NativeLoginProgressScreen extends StatelessWidget {
  const NativeLoginProgressScreen({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: _loginSystemBars,
    child: Scaffold(
      backgroundColor: DocColors.primary,
      body: const SafeArea(
        bottom: false,
        // The first white LinearLayout remains visible when login_full_layout
        // is GONE; it covers the root's green_gray_background drawable.
        child: ColoredBox(
          color: Colors.white,
          child: Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: DocColors.primary,
                strokeWidth: 4,
                semanticsLabel: 'Logging in',
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
