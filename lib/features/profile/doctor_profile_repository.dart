import 'dart:convert';
import 'dart:typed_data';

import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';
import '../auth/account_access.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';

class DoctorProfileDetails {
  DoctorProfileDetails(JsonMap values, {this.picture})
    : values = Map.unmodifiable(values);
  final JsonMap values;
  final Uint8List? picture;
  String value(String key) => nativeText(values[key]);

  DoctorProfileDetails withPicture(Uint8List bytes) =>
      DoctorProfileDetails(values, picture: Uint8List.fromList(bytes));
}

class DoctorProfileRepository {
  DoctorProfileRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;

  void _doctor(AuthSession session, AccountProfile profile) {
    if (!profile.isDoctor ||
        session.account.role != AccountRole.doctor ||
        profile.doctorId.isEmpty ||
        profile.value('doc_code') != session.account.doctorCode) {
      throw const AppFailure(
        'Could Not Get Doctor Data. Please return to Login.',
        kind: FailureKind.invalidData,
      );
    }
    ProfileRepository.checkAccess(profile, now());
  }

  Future<DoctorProfileDetails> load(
    AuthSession session,
    AccountProfile profile, {
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) {
      throw const ObsoleteRequest();
    }
    _doctor(session, profile);
    final root = await transport.get(
      apiEndpoint(session.center.baseUri, 'doc_profile/getDocProfile', {
        'doc_id': profile.doctorId,
      }),
    );
    if (!isCurrent()) {
      throw const ObsoleteRequest();
    }
    _doctor(session, profile);
    if (!root.containsKey('count') ||
        (nativeText(root['count']) != '0' && root['items'] == null)) {
      throw const AppFailure('The server returned incomplete doctor data.');
    }
    // Native count=0 displays empty address/contact and the doctor placeholder.
    final rows =
        nativeText(root['count']) == '0' ? <JsonMap>[] : nativeItems(root);
    final values = rows.isEmpty ? <String, Object?>{} : rows.last;
    if (rows.isNotEmpty &&
        !const [
          'doc_village',
          'doc_poffice',
          'dd_thana_name',
          'dist_name',
          'doc_cell',
          'doc_phone',
          'doc_email',
          'doc_dd_id',
          'dist_id',
        ].every(values.containsKey)) {
      throw const AppFailure('The server returned incomplete doctor data.');
    }
    Uint8List? picture;
    final encoded = nativeText(values['doc_profile_pic']);
    if (encoded.isNotEmpty) {
      try {
        picture = base64Decode(encoded.replaceAll(RegExp(r'\s+'), ''));
        if (picture.isEmpty) {
          picture = null;
        }
      } on FormatException {
        // Android Bitmap decode failure uses the same doctor placeholder.
        picture = null;
      }
    }
    return DoctorProfileDetails(values, picture: picture);
  }

  Future<void> upload(
    AuthSession session,
    AccountProfile profile,
    Uint8List jpeg, {
    required bool Function() isCurrent,
    required bool Function() isForeground,
  }) async {
    void guard() {
      if (!isCurrent() || !isForeground()) {
        throw const ObsoleteRequest();
      }
    }

    guard();
    _doctor(session, profile);
    if (jpeg.length < 4 ||
        jpeg.length > 1024 * 1024 ||
        jpeg[0] != 0xff ||
        jpeg[1] != 0xd8 ||
        jpeg[jpeg.length - 2] != 0xff ||
        jpeg.last != 0xd9) {
      throw const AppFailure('Invalid image. Please choose another picture.');
    }
    final writer = transport;
    if (writer is! BinaryTransport) {
      throw const AppFailure('Picture upload is unavailable in this build.');
    }
    final flag = await transport.get(
      apiEndpoint(session.center.baseUri, 'doc_dashboard/getDocFLFlag', {
        'p_doc_id': profile.doctorId,
      }),
    );
    guard();
    final flags =
        nativeText(flag['count']) == '0' ? <JsonMap>[] : nativeItems(flag);
    if (flags.isEmpty ||
        !flags.first.containsKey('fl_flag') ||
        !const ['0', '1'].contains(nativeText(flags.first['fl_flag']))) {
      throw const AppFailure(
        'Account access could not be verified. Please try again.',
      );
    }
    if (nativeText(flags.first['fl_flag']) == '1') {
      throw const AccountAccessFailure.forcedLogout();
    }
    _doctor(session, profile);
    guard();
    final response = await writer.postBytes(
      apiEndpoint(session.center.baseUri, 'doc_profile/updateImage'),
      jpeg,
      headers: {'p_doc_id': profile.doctorId},
    );
    // Do not convert a background success into a second POST on resume.
    if (!isCurrent()) {
      throw const ObsoleteRequest();
    }
    final result = nativeText(response['string_out']);
    if (result != 'Successfully Created') {
      throw AppFailure(result.isEmpty ? 'Picture upload failed.' : result);
    }
  }
}
