import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';
import '../auth/account_access.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';

class DoctorThana {
  const DoctorThana({
    required this.id,
    required this.districtId,
    required this.name,
    required this.district,
  });
  final String id, districtId, name, district;

  /// Android's name lookup walks the whole list, retaining its last match.
  static DoctorThana? named(Iterable<DoctorThana> items, String name) {
    DoctorThana? match;
    for (final item in items) {
      if (item.name == name) {
        match = item;
      }
    }
    return match;
  }
}

class DoctorAddressDraft {
  const DoctorAddressDraft({
    required this.street,
    required this.postOffice,
    required this.thanaId,
  });
  final String street, postOffice, thanaId;

  String? get validationMessage {
    if (street.trim().isEmpty) {
      return 'Please Provide Street Address/Village';
    }
    if (postOffice.trim().isEmpty) {
      return 'Please Provide Post Office';
    }
    if (thanaId.trim().isEmpty) {
      return 'Please Select Thana/Upazila';
    }
    if ([
      street,
      postOffice,
      thanaId,
    ].any((v) => v.contains(RegExp(r'[\r\n]')))) {
      return 'Please enter the address on a single line.';
    }
    return null;
  }
}

class DoctorAddressRepository {
  DoctorAddressRepository(this.transport, {DateTime Function()? now})
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

  Future<List<DoctorThana>> loadThanas(
    AuthSession session,
    AccountProfile profile, {
    required bool Function() isCurrent,
  }) async {
    void guard() {
      if (!isCurrent()) {
        throw const ObsoleteRequest();
      }
      _doctor(session, profile);
    }

    guard();
    final root = await transport.get(
      apiEndpoint(session.center.baseUri, 'doc_profile/getDocThana'),
    );
    guard();
    final count = int.tryParse(nativeText(root['count']));
    if (count == null || count < 0 || (count > 0 && root['items'] == null)) {
      throw const AppFailure(
        'The server returned incomplete Thana/Upazila data.',
      );
    }
    if (count == 0) {
      return const [];
    }
    final rows = nativeItems(root);
    if (rows.isEmpty ||
        rows.any(
          (row) =>
              !const [
                'dd_id',
                'dd_dist_id',
                'dd_thana_name',
                'dist_name',
              ].every(row.containsKey),
        )) {
      throw const AppFailure(
        'The server returned incomplete Thana/Upazila data.',
      );
    }
    return List.unmodifiable([
      for (final row in rows)
        DoctorThana(
          id: nativeText(row['dd_id']),
          districtId: nativeText(row['dd_dist_id']),
          name: nativeText(row['dd_thana_name']),
          district: nativeText(row['dist_name']),
        ),
    ]);
  }

  Future<void> update(
    AuthSession session,
    AccountProfile profile,
    DoctorAddressDraft address, {
    required bool Function() isCurrent,
    required bool Function() isForeground,
  }) async {
    void guard() {
      if (!isCurrent() || !isForeground()) {
        throw const ObsoleteRequest();
      }
      _doctor(session, profile);
    }

    guard();
    final invalid = address.validationMessage;
    if (invalid != null) {
      throw AppFailure(invalid, kind: FailureKind.invalidData);
    }
    final flag = await transport.get(
      apiEndpoint(session.center.baseUri, 'doc_dashboard/getDocFLFlag', {
        'p_doc_id': profile.doctorId,
      }),
    );
    guard();
    final rows =
        nativeText(flag['count']) == '0' ? <JsonMap>[] : nativeItems(flag);
    if (rows.isEmpty ||
        !const ['0', '1'].contains(nativeText(rows.first['fl_flag']))) {
      throw const AppFailure(
        'Account access could not be verified. Please try again.',
      );
    }
    if (nativeText(rows.first['fl_flag']) == '1') {
      throw const AccountAccessFailure.forcedLogout();
    }
    guard();
    final response = await transport.post(
      apiEndpoint(session.center.baseUri, 'doc_profile/updateAddress'),
      headers: {
        'P_S_ADDRESS': address.street,
        'P_POST_OFFICE': address.postOffice,
        'P_DD_ID': address.thanaId,
        'P_DOC_ID': profile.doctorId,
      },
    );
    // A response received in the background still belongs to this one POST.
    if (!isCurrent()) {
      throw const ObsoleteRequest();
    }
    final result = nativeText(response['string_out']);
    if (result != 'Successfully Created') {
      throw AppFailure(result.isEmpty ? 'Address update failed.' : result);
    }
  }
}
