import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

/// Daily and employee attendance share the same enabled/disabled field appearance.
/// Catalogue choices and popup ownership stay with their respective screens.
InputDecoration nativeAttendanceFilterDecoration({
  required String label,
  required bool enabled,
  required double sdp,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: DocColors.primary),
  );
  return InputDecoration(
    labelText: label,
    enabled: enabled,
    labelStyle: TextStyle(
      fontFamily: 'OpenSans',
      fontFamilyFallback: const ['DocDiaryBengali'],
      fontSize: 10 * sdp,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: enabled ? const Color(0xff6c6e6f) : DocColors.muted,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    filled: true,
    fillColor: enabled ? Colors.white : const Color(0xfff5f5f5),
    suffixIcon: const Icon(Icons.arrow_drop_down),
    enabledBorder: border,
    disabledBorder: border,
  );
}
