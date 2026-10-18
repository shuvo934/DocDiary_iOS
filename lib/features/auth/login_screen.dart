import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_controller.dart';
import 'native_login_layout.dart';

export 'native_login_layout.dart' show NativeLoginProgressScreen;
export 'native_selection_screen.dart' show SelectionScreen;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});
  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  bool _remember = false;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    final saved = widget.controller.formCredentials;
    if (saved != null) {
      _mobile.text = saved.mobile;
      _password.text = saved.password;
      _remember = widget.controller.formRemember;
    }
    final initialError = widget.controller.error;
    if (initialError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.stage == AuthStage.signedOut) {
          unawaited(_showError(initialError));
        }
      });
    }
  }

  @override
  void dispose() {
    _mobile.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (widget.controller.busy) {
      return;
    }
    await widget.controller.login(
      _mobile.text,
      _password.text,
      remember: _remember,
    );
    if (!mounted || widget.controller.stage != AuthStage.signedOut) {
      return;
    }
    final error = widget.controller.error;
    if (error != null) {
      await _showError(error);
    }
  }

  Future<void> _showError(String message) async {
    if (message == 'Please Give Mobile No and Password') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final retry =
        message == 'Server Problem or Internet Not Connected' ||
        message == 'There is a network issue in the server. Please Try later.';
    final shouldRetry = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Image.asset(
                  'assets/images/doc_diary_default.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 12),
                const Text('Warning!'),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, retry),
                child: Text(retry ? 'Retry' : 'OK'),
              ),
            ],
          ),
    );
    if (mounted && shouldRetry == true) {
      await _submit();
    }
  }

  Future<void> _contact() async {
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => PopScope(
            canPop: false,
            child: AlertDialog(
              content: const Text(
                'Do you want to send an email to info@techterrain-it.com ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes'),
                ),
              ],
            ),
          ),
    );
    if (approved != true || !mounted) return;
    const body =
        'Please fill out the field to create your user id.\n\n'
        'Center/Hospital Name: \nCenter/Hospital Address: \nUser Name: \n'
        'User Mobile No: \nUser Designation: \nUser Mail: \nUser Code(If any): ';
    final uri = Uri(
      scheme: 'mailto',
      path: 'info@techterrain-it.com',
      query:
          'subject=${Uri.encodeComponent('New Account Creation Request From DocDiary')}'
          '&body=${Uri.encodeComponent(body)}',
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('There is no email app found.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('There is no email app found.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.busy) {
      return const NativeLoginProgressScreen();
    }
    return NativeLoginLayout(
      mobile: _mobile,
      password: _password,
      remember: _remember,
      hidePassword: _hidePassword,
      onRememberChanged: (value) => setState(() => _remember = value),
      onTogglePassword: () => setState(() => _hidePassword = !_hidePassword),
      onDone: () => FocusScope.of(context).unfocus(),
      onSubmit: () => unawaited(_submit()),
      onContact: () => unawaited(_contact()),
    );
  }
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFA33220), fontSize: 14),
      ),
    ),
  );
}
