import 'dart:convert';

import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/profile/doctor_address_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_support.dart';
import 'support.dart';

DoctorAddressRepository _repo(Harness h) =>
    DoctorAddressRepository(h.transport, now: () => h.now);
const _draft = DoctorAddressDraft(
  street: 'House 12, Example Road',
  postOffice: 'Savar',
  thanaId: '12',
);
Future<List<DoctorThana>> _load(
  Harness h, {
  AccountProfile? profile,
  bool Function()? current,
}) => _repo(h).loadThanas(
  h.auth.session!,
  profile ?? h.auth.profile!,
  isCurrent: current ?? () => true,
);
Future<void> _save(
  Harness h, {
  DoctorAddressDraft draft = _draft,
  AccountProfile? profile,
  bool Function()? current,
  bool Function()? foreground,
}) => _repo(h).update(
  h.auth.session!,
  profile ?? h.auth.profile!,
  draft,
  isCurrent: current ?? () => true,
  isForeground: foreground ?? () => true,
);

void main() {
  test(
    'Thana directory uses native endpoint without query, headers or login writes',
    () async {
      final h = profileHarness();
      await h.signIn();
      final posts = h.posts.length;
      final data = await _load(h);
      expect(
        h.transport.requests.last.uri.toString(),
        'https://centre.example/api/doc_profile/getDocThana',
      );
      expect(h.transport.requests.last.headers, isEmpty);
      expect(data.first.id, '12');
      expect(data.first.districtId, '1');
      expect(data.first.name, 'Savar');
      expect(data.first.district, 'Dhaka');
      expect(h.posts.length, posts);
    },
  );
  test(
    'encoded ORDS rows, numeric ids and null strings follow native normalization',
    () async {
      final h = profileHarness();
      await h.signIn();
      h.transport.onGet =
          (_) async => {
            'count': '1',
            'items': jsonEncode([
              {
                'dd_id': 12,
                'dd_dist_id': 1,
                'dd_thana_name': 'null',
                'dist_name': null,
              },
            ]),
          };
      final item = (await _load(h)).single;
      expect(item.id, '12');
      expect(item.districtId, '1');
      expect(item.name, '');
      expect(item.district, '');
      h.transport.onGet = (_) async => {'count': '0', 'items': null};
      expect(await _load(h), isEmpty);
    },
  );
  test('incomplete directory does not become a false empty list', () async {
    final h = profileHarness();
    await h.signIn();
    for (final response in <JsonMap>[
      {},
      {'count': null},
      {'count': 'unknown'},
      {'count': -1},
      {'count': 1, 'items': null},
      {'count': 1, 'items': 'bad json'},
      {'count': 1, 'items': []},
      {
        'count': 1,
        'items': [
          {'dd_id': '12'},
        ],
      },
    ]) {
      h.transport.onGet = (_) async => response;
      await expectLater(_load(h), throwsA(isA<AppFailure>()));
    }
  });
  test(
    'duplicate names retain native last match and require exact spelling',
    () {
      const first = DoctorThana(
        id: '1',
        districtId: '1',
        name: 'Sadar',
        district: 'First',
      );
      const last = DoctorThana(
        id: '2',
        districtId: '2',
        name: 'Sadar',
        district: 'Last',
      );
      expect(DoctorThana.named([first, last], 'Sadar'), same(last));
      expect(DoctorThana.named([first, last], 'sadar'), isNull);
    },
  );
  test(
    'save uses exact native header names, unchanged values and success response',
    () async {
      final h = profileHarness();
      await h.signIn();
      final loginWrites = h.posts.length;
      const draft = DoctorAddressDraft(
        street: '  House 12 / Road 3  ',
        postOffice: 'P.O. Savar',
        thanaId: '12',
      );
      await _save(h, draft: draft);
      expect(h.posts.length, loginWrites + 1);
      final request = h.posts.last;
      expect(
        request.uri.toString(),
        'https://centre.example/api/doc_profile/updateAddress',
      );
      expect(request.headers, {
        'P_S_ADDRESS': '  House 12 / Road 3  ',
        'P_POST_OFFICE': 'P.O. Savar',
        'P_DD_ID': '12',
        'P_DOC_ID': '10',
      });
      final flag = h.transport.requests[h.transport.requests.length - 2];
      expect(flag.uri.path, endsWith('/doc_dashboard/getDocFLFlag'));
      expect(flag.uri.queryParameters, {'p_doc_id': '10'});
      expect(h.transport.binaryRequests, isEmpty);
    },
  );
  test(
    'empty, whitespace and line-break address values cannot dispatch',
    () async {
      final h = profileHarness();
      await h.signIn();
      final requests = h.transport.requests.length;
      for (final draft in [
        const DoctorAddressDraft(street: ' ', postOffice: 'P', thanaId: '1'),
        const DoctorAddressDraft(street: 'S', postOffice: '', thanaId: '1'),
        const DoctorAddressDraft(street: 'S', postOffice: 'P', thanaId: ''),
        const DoctorAddressDraft(
          street: 'S\r\nInjected',
          postOffice: 'P',
          thanaId: '1',
        ),
      ]) {
        await expectLater(_save(h, draft: draft), throwsA(isA<AppFailure>()));
      }
      expect(h.transport.requests.length, requests);
    },
  );
  test(
    'admin, different doctor, expired and denied accounts cannot load or save',
    () async {
      final h = profileHarness();
      await h.signIn();
      final requests = h.transport.requests.length;
      for (final profile in [
        AccountProfile(AccountRole.admin, adminProfile()),
        AccountProfile(AccountRole.doctor, {
          ...h.doctorData,
          'doc_code': 'D-OTHER',
        }),
        AccountProfile(AccountRole.doctor, {
          ...h.doctorData,
          'exp_date': '01-JAN-20',
        }),
        AccountProfile(AccountRole.doctor, {
          ...h.doctorData,
          'access_flag': '0',
        }),
      ]) {
        await expectLater(
          _load(h, profile: profile),
          throwsA(isA<AppFailure>()),
        );
        await expectLater(
          _save(h, profile: profile),
          throwsA(isA<AppFailure>()),
        );
      }
      expect(h.transport.requests.length, requests);
    },
  );
  test(
    'forced logout and incomplete flag block POST before dispatch',
    () async {
      final h = profileHarness();
      await h.signIn();
      final posts = h.posts.length;
      for (final response in <JsonMap>[
        {'count': 0, 'items': null},
        {
          'items': [
            {'fl_flag': '1'},
          ],
        },
        {
          'items': [
            {'fl_flag': 'unknown'},
          ],
        },
      ]) {
        h.transport.onGet = (_) async => response;
        await expectLater(_save(h), throwsA(isA<AppFailure>()));
      }
      expect(h.posts.length, posts);
    },
  );
  test(
    'stale reads and a backgrounded preflight cannot commit or POST',
    () async {
      final h = profileHarness();
      await h.signIn();
      var current = true;
      h.transport.onGet = (_) async {
        current = false;
        return {'count': 3, 'items': profileThanas()};
      };
      await expectLater(
        _load(h, current: () => current),
        throwsA(isA<ObsoleteRequest>()),
      );
      var foreground = true;
      h.transport.onGet = (_) async {
        foreground = false;
        return {
          'items': [
            {'fl_flag': '0'},
          ],
        };
      };
      final posts = h.posts.length;
      await expectLater(
        _save(h, foreground: () => foreground),
        throwsA(isA<ObsoleteRequest>()),
      );
      expect(h.posts.length, posts);
    },
  );
  test(
    'a successful background response completes one POST without replay',
    () async {
      final h = profileHarness();
      await h.signIn();
      var foreground = true;
      h.transport.onPost = (_, _) async {
        foreground = false;
        return {'string_out': 'Successfully Created'};
      };
      await _save(h, foreground: () => foreground);
      expect(
        h.posts.where((r) => r.uri.path.endsWith('updateAddress')),
        hasLength(1),
      );
    },
  );
  test(
    'network errors and every non-success response remain explicit failures with no automatic retry',
    () async {
      final h = profileHarness();
      await h.signIn();
      for (final response in <JsonMap>[
        {'string_out': 'Rejected'},
        {'string_out': 'successfully created'},
        {'string_out': null},
        {},
      ]) {
        h.transport.onPost = (_, _) async => response;
        await expectLater(_save(h), throwsA(isA<AppFailure>()));
      }
      h.transport.onPost =
          (_, _) async => throw const AppFailure('Network interrupted');
      await expectLater(_save(h), throwsA(isA<AppFailure>()));
      expect(
        h.posts.where((r) => r.uri.path.endsWith('updateAddress')),
        hasLength(5),
      );
    },
  );
}
