import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../core/failure.dart';
import 'dashboard_navigation.dart';

enum DashboardPhotoSource { camera, gallery }

image.Image _decodeDashboardImage(Uint8List bytes) {
  try {
    final decoded = image.decodeImage(bytes);
    if (decoded != null) {
      return decoded;
    }
  } catch (_) {
    // Some image decoders throw RangeError/codec exceptions for truncated data.
    // Convert only this decoding failure to the native user-facing error flow.
  }
  throw const AppFailure('Invalid image. Please choose another picture.');
}

/// The iOS camera plugin mirrors the front preview, but not its still JPEG.
/// Bake EXIF rotation and mirror the still as Native CameraPreview does, so
/// retake/confirmation and the cropper all display the same orientation.
Uint8List orientDashboardCapture(({Uint8List bytes, bool mirror}) capture) {
  final decoded = _decodeDashboardImage(capture.bytes);
  var oriented = image.bakeOrientation(decoded);
  if (capture.mirror) {
    oriented = image.flipHorizontal(oriented);
  }
  oriented.exif.clear();
  oriented.iccProfile = null;
  return image.encodeJpg(oriented, quality: 100);
}

abstract interface class DashboardPhotoMedia {
  Future<Uint8List?> select(
    DashboardPhotoSource source, {
    required Future<String?> Function() capture,
    required Future<bool> Function() ready,
  });
}

abstract interface class DashboardReview {
  Future<void> request();
}

class DashboardServices {
  const DashboardServices({
    this.media = const IosDashboardPhotoMedia(),
    this.review = const IosDashboardReview(),
    this.destinationBuilder,
  });
  final DashboardPhotoMedia media;
  final DashboardReview review;
  final DashboardDestinationBuilder? destinationBuilder;
}

class IosDashboardPhotoMedia implements DashboardPhotoMedia {
  const IosDashboardPhotoMedia();

  @override
  Future<Uint8List?> select(
    DashboardPhotoSource source, {
    required Future<String?> Function() capture,
    required Future<bool> Function() ready,
  }) async {
    String? original;
    String? croppedPath;
    try {
      original =
          source == DashboardPhotoSource.camera
              ? await capture()
              : (await ImagePicker().pickImage(
                source: ImageSource.gallery,
                requestFullMetadata: false,
              ))?.path;
      if (original == null || !await ready()) {
        return null;
      }
      // Native uCrop has a free aspect ratio, rotation and a 1080px result limit.
      final cropped = await ImageCropper().cropImage(
        sourcePath: original,
        maxWidth: 1080,
        maxHeight: 1080,
        compressQuality: 100,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          IOSUiSettings(
            title: 'Crop',
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
            aspectRatioLockEnabled: false,
          ),
        ],
      );
      croppedPath = cropped?.path;
      if (croppedPath == null || !await ready()) {
        return null;
      }
      final bytes = await File(croppedPath).readAsBytes();
      return await compute(prepareDashboardJpeg, bytes);
    } on PlatformException catch (failure) {
      final denied =
          failure.code.toLowerCase().contains('access_denied') ||
          failure.code.toLowerCase().contains('permission');
      throw AppFailure(
        denied
            ? 'Photo access is unavailable. Allow DocDiary access in iPhone Settings, then try again.'
            : 'Failed to read image. Please choose another picture.',
      );
    } on FileSystemException {
      throw const AppFailure(
        'Failed to read image. Please choose another picture.',
      );
    } finally {
      // Both paths are plugin-created temporary copies, never a user's album.
      for (final path in {original, croppedPath}.whereType<String>()) {
        try {
          await File(path).delete();
        } on FileSystemException {
          // The picker/cropper may already have removed its temporary file.
        }
      }
    }
  }
}

/// Matches native resize-to-fit(1080,1080), including upscaling, then JPEG
/// quality 100,95,...,10. Unlike native's integer-KB comparison, a strict 1MiB
/// bound prevents an oversized request; failure retains the previous picture.
Uint8List prepareDashboardJpeg(Uint8List bytes) {
  final decoded = _decodeDashboardImage(bytes);
  final oriented = image.bakeOrientation(decoded);
  final scale =
      1080 /
      (oriented.width > oriented.height ? oriented.width : oriented.height);
  final resized = image.copyResize(
    oriented,
    width: (oriented.width * scale).round().clamp(1, 1080),
    height: (oriented.height * scale).round().clamp(1, 1080),
    interpolation: image.Interpolation.linear,
  );
  // Camera/cropper metadata is not needed by the legacy binary upload endpoint.
  resized.exif.clear();
  resized.iccProfile = null;
  for (var quality = 100; quality >= 10; quality -= 5) {
    final encoded = image.encodeJpg(resized, quality: quality);
    if (encoded.length <= 1024 * 1024) {
      return encoded;
    }
  }
  throw const AppFailure(
    'Picture is too large. Please crop it smaller and try again.',
  );
}

class IosDashboardReview implements DashboardReview {
  const IosDashboardReview();

  @override
  Future<void> request() async {
    // Debug iOS always presents the test sheet. Keep development uninterrupted.
    if (!kReleaseMode || !Platform.isIOS) {
      return;
    }
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } on PlatformException {
      // Review availability/display never blocks a successful dashboard load.
    } on MissingPluginException {
      // Optional integration; it cannot change authentication or dashboard data.
    }
  }
}
