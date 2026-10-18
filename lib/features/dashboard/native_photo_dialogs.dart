import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'dashboard_services.dart';
import 'native_dashboard_dialogs.dart';
import 'native_photo_icons.dart';

class NativePhotoChoiceDialog extends StatelessWidget {
  const NativePhotoChoiceDialog({super.key});

  Widget _choice(
    BuildContext context,
    DashboardPhotoSource source,
    double sdp,
  ) => Expanded(
    child: Material(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(8 * sdp),
      child: InkWell(
        key: Key('dashboard_photo_${source.name}'),
        borderRadius: BorderRadius.circular(8 * sdp),
        onTap: () => Navigator.pop(context, source),
        child: Padding(
          padding: EdgeInsets.all(8 * sdp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NativePhotoIcon(
                source == DashboardPhotoSource.camera
                    ? NativePhotoGlyph.camera
                    : NativePhotoGlyph.gallery,
                size: 44 * sdp,
                color: DocColors.primary,
              ),
              Text(
                source.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: dashboardDialogText(
                  13 * sdp,
                  family: 'Baloo',
                  color: DocColors.greenSea,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).shortestSide;
    final sdp = width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
    return Dialog(
      key: const Key('dashboard_photo_choice'),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width:
            math
                .min(MediaQuery.sizeOf(context).width * .95 - 32, 560)
                .toDouble(),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColoredBox(
                color: DocColors.primary,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4, right: 6),
                          child: Text(
                            'Upload Picture via',
                            style: dashboardDialogText(
                              18,
                              family: 'Poppins',
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('dashboard_photo_close'),
                        tooltip: 'Close',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const NativePhotoIcon(
                          NativePhotoGlyph.close,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12 * sdp),
                child: Row(
                  children: [
                    _choice(context, DashboardPhotoSource.camera, sdp),
                    SizedBox(width: 12 * sdp),
                    _choice(context, DashboardPhotoSource.gallery, sdp),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NativePhotoRetryDialog extends StatelessWidget {
  const NativePhotoRetryDialog({super.key, required this.failure});
  final Object failure;

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('dashboard_photo_error'),
    title: Text(
      'Error!',
      style: dashboardDialogText(20, weight: FontWeight.w500),
    ),
    content: SingleChildScrollView(
      child: Text(
        dashboardErrorMessage(failure),
        style: dashboardDialogText(16),
      ),
    ),
    actions: [
      TextButton(
        key: const Key('dashboard_photo_cancel'),
        onPressed: () => Navigator.pop(context, false),
        child: Text(
          'Cancel',
          style: dashboardDialogText(14, color: DocColors.primary),
        ),
      ),
      TextButton(
        key: const Key('dashboard_photo_retry'),
        onPressed: () => Navigator.pop(context, true),
        child: Text(
          'Retry',
          style: dashboardDialogText(14, color: DocColors.primary),
        ),
      ),
    ],
  );
}
