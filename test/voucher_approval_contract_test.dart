import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/accounts/voucher_approval/voucher_approval_models.dart';
import 'package:docdiary_ios/features/accounts/voucher_transaction/voucher_models.dart';
import 'voucher_approval_test_support.dart';

void main() {
  late ApprovalHarness h;
  setUp(() async {
    h = ApprovalHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  Future<ApprovalVoucherDetail> load(VoucherApprovalKind k, int i) =>
      h.approvals.details(
        h.auth.session!,
        h.profile,
        h.choice(k, i),
        isCurrent: () => true,
      );
  for (final kind in VoucherApprovalKind.values) {
    test(
      '${kind.code} latest contract, order, actual IDs and native audit labels',
      () async {
        final rows = await h.approvals.latest(
          h.auth.session!,
          h.profile,
          kind,
          isCurrent: () => true,
        );
        expect(rows.map((v) => v.id), h.choices[kind]!.map((r) => r['vm_id']));
        expect(rows.where((v) => v.approved).length, 3);
        expect(rows.where((v) => !v.approved).length, 1);
        expect(rows.first.prefix, 'EXAMPLE.${kind.code}.');
        expect(rows[1].auditUserLabel, 'Disapproved By:');
        expect(rows[1].auditTimeLabel, 'Disapproved Time:');
        expect(h.approvalReads.single.uri.queryParameters, {
          'v_type': kind.code,
        });
        expect(
          h.approvalReads.single.uri.pathSegments.last,
          'getVoucherSelectListHundred',
        );
      },
    );
    for (final action in VoucherApprovalAction.values) {
      test(
        '${kind.code} ${action.name} rechecks ledger then sends exactly native headers',
        () async {
          final index = action == VoucherApprovalAction.approve ? 1 : 0,
              shown = await load(kind, index);
          h.transport.requests.clear();
          await h.approvals.submit(
            h.auth.session!,
            h.profile,
            shown,
            action,
            isCurrent: () => true,
          );
          expect(h.approvalReads.map((r) => r.uri.pathSegments.last), [
            'getVoucherDetails',
            'updateVoucher',
          ]);
          final post = h.updates.single;
          expect(post.method, 'POST');
          expect(post.uri.queryParameters, isEmpty);
          expect(post.headers, {
            'P_VM_ID': shown.voucher.id,
            'P_APPROVE_FLAG': action.flag,
            'P_USER_ID': h.profile.value('usr_name'),
          });
          expect(h.choice(kind, index).flag, action.flag);
        },
      );
    }
  }
  test(
    'ORDS encoded items and encoded voucher_list preserve metadata and ledger cents',
    () async {
      h.encoded = true;
      h.encodeNested = true;
      final rows = h.ledgerFor(VoucherApprovalKind.credit, 0);
      rows[0]['vd_dr_amt'] = '139.05';
      rows[1]['vd_cr_amt'] = '139.050';
      final d = await load(VoucherApprovalKind.credit, 0);
      expect(d.value('vm_user'), 'Example Prepared User');
      expect(d.lines.first.value('ad_code'), '010101001');
      expect(d.lines.first.value('vd_cheque_no'), '000');
      expect(d.debit.text, '139.05');
      expect(d.credit.text, '139.05');
      expect(d.balanced, isTrue);
    },
  );
  test('native null detail approval flag defaults to pending', () async {
    for (final line in h.ledgerFor(VoucherApprovalKind.credit, 1)) {
      line['vm_voucher_approved_flag'] = null;
    }
    final detail = await load(VoucherApprovalKind.credit, 1);
    expect(detail.action, VoucherApprovalAction.approve);
    expect(detail.lines.first.value('vm_voucher_approved_flag'), '0');
  });
  test('native prefix and query validation do not invent a centre prefix', () {
    final r = approvalChoice(VoucherApprovalKind.credit, 1)
      ..['vm_no'] = 'NO_PREFIX';
    expect(ApprovalVoucher(VoucherApprovalKind.credit, r).prefix, '');
    expect(validateVoucherQuery('123', ''), isNull);
    expect(
      validateVoucherQuery('', 'EXAMPLE.CV.'),
      'Please Provide Voucher No',
    );
    expect(
      validateVoucherQuery('12', 'EXAMPLE.CV.'),
      'Voucher No must be greater than 2 character',
    );
    expect(
      validateVoucherQuery('.123', 'EXAMPLE.CV.'),
      contains('should not start'),
    );
    expect(
      validateVoucherQuery('EXAMPLE.CV.123', 'EXAMPLE.CV.'),
      contains('must not include'),
    );
  });
  test(
    'search uses native endpoint and URI-encodes only supplied suffix',
    () async {
      h.onApprovalGet =
          (u) async =>
              u.pathSegments.last == 'getVoucherSelectListBySearch'
                  ? h.page([])
                  : null;
      await h.approvals.search(
        h.auth.session!,
        h.profile,
        VoucherApprovalKind.credit,
        '123 &more=7',
        'EXAMPLE.CV.',
        isCurrent: () => true,
      );
      final r = h.approvalReads.single;
      expect(r.uri.pathSegments.last, 'getVoucherSelectListBySearch');
      expect(r.uri.queryParameters, {'v_type': 'CV', 'p_vm_no': '123 &more=7'});
      expect(r.method, 'GET');
    },
  );
  test('invalid search never starts a ledger GET', () async {
    for (final q in ['', 'ab', '.123', 'EXAMPLE.CV.001']) {
      await expectLater(
        h.approvals.search(
          h.auth.session!,
          h.profile,
          VoucherApprovalKind.credit,
          q,
          'EXAMPLE.CV.',
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(h.approvalReads, isEmpty);
  });
  test(
    'selection rejects missing fields, mismatched type and ambiguous status',
    () {
      for (final key in ApprovalVoucher.fields) {
        final row = approvalChoice(VoucherApprovalKind.credit, 1)..remove(key);
        expect(
          () => ApprovalVoucher(VoucherApprovalKind.credit, row),
          throwsA(isA<AppFailure>()),
        );
      }
      final r = approvalChoice(VoucherApprovalKind.credit, 1)
        ..['status'] = 'Pending';
      expect(
        () => ApprovalVoucher(VoucherApprovalKind.credit, r),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => ApprovalVoucher(
          VoucherApprovalKind.debit,
          approvalChoice(VoucherApprovalKind.credit, 1),
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'approved missing name and never-disapproved pending fields retain native wording',
    () {
      final a = approvalChoice(VoucherApprovalKind.credit, 1)
        ..['approved_user'] = null;
      final p = approvalChoice(VoucherApprovalKind.credit, 2, approved: false)
        ..['approved_user'] = null;
      expect(
        ApprovalVoucher(VoucherApprovalKind.credit, a).auditUser,
        'No Name found',
      );
      expect(
        ApprovalVoucher(VoucherApprovalKind.credit, p).auditUserLabel,
        'Approved By / Disapproved By:',
      );
      expect(
        ApprovalVoucher(VoucherApprovalKind.credit, p).auditTimeLabel,
        'Approved / Disapproved Time:',
      );
    },
  );
  test(
    'first detail row metadata, source order and repeated equal rows are retained',
    () async {
      final rows = h.ledgerFor(VoucherApprovalKind.credit, 0);
      rows.add({...rows.first, 'vd_id': '3'});
      rows[1]['vm_naration'] = 'later metadata';
      final d = await load(VoucherApprovalKind.credit, 0);
      expect(d.lines.length, 3);
      expect(d.debit.text, '366000');
      expect(d.value('vm_naration'), 'Synthetic voucher 1');
    },
  );
  test(
    'empty details remain read-only and missing nested data is rejected',
    () async {
      h.onApprovalGet =
          (u) async =>
              u.pathSegments.last == 'getVoucherDetails' ? h.page([]) : null;
      final empty = await load(VoucherApprovalKind.credit, 0);
      expect(empty.empty, isTrue);
      await expectLater(
        h.approvals.submit(
          h.auth.session!,
          h.profile,
          empty,
          VoucherApprovalAction.disapprove,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.updates, isEmpty);
      h.onApprovalGet =
          (u) async =>
              u.pathSegments.last == 'getVoucherDetails' ? h.page([{}]) : null;
      await expectLater(
        load(VoucherApprovalKind.credit, 0),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'wrong voucher ID/no, missing ledger field, and malformed amounts reject partial detail',
    () async {
      for (final key in ['vm_id', 'vm_no', 'vd_dr_amt', 'ad_code']) {
        final row = h.ledgerFor(VoucherApprovalKind.credit, 0).first,
            old = Map<String, Object?>.of(row);
        if (key == 'ad_code') {
          row.remove(key);
        } else {
          row[key] = key == 'vd_dr_amt' ? 'bad' : 'other';
        }
        await expectLater(
          load(VoucherApprovalKind.credit, 0),
          throwsA(isA<AppFailure>()),
        );
        row
          ..clear()
          ..addAll(old);
      }
    },
  );
  test(
    'mismatched envelope counts and absent item data are rejected',
    () async {
      for (final response in <JsonMap>[
        {'count': 2, 'items': []},
        {'count': 0},
        {'count': 'bad', 'items': []},
        {'count': -1, 'items': []},
      ]) {
        h.onApprovalGet = (_) async => response;
        await expectLater(
          h.approvals.latest(
            h.auth.session!,
            h.profile,
            VoucherApprovalKind.credit,
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
      }
    },
  );
  test(
    'Debit imbalance is blocked; Credit/Journal retain native approval rule',
    () async {
      for (final kind in VoucherApprovalKind.values) {
        h.ledgerFor(kind, 1)[0]['vd_dr_amt'] = '139.05';
        final shown = await load(kind, 1);
        final submit = h.approvals.submit(
          h.auth.session!,
          h.profile,
          shown,
          VoucherApprovalAction.approve,
          isCurrent: () => true,
        );
        if (kind == VoucherApprovalKind.debit) {
          await expectLater(submit, throwsA(isA<AppFailure>()));
        } else {
          await submit;
        }
      }
      expect(h.updates.length, 2);
    },
  );
  test('changed status or amounts after confirmation never POST', () async {
    var shown = await load(VoucherApprovalKind.credit, 1);
    h.ledgerFor(VoucherApprovalKind.credit, 1)[0]['vd_dr_amt'] = '183001';
    await expectLater(
      h.approvals.submit(
        h.auth.session!,
        h.profile,
        shown,
        VoucherApprovalAction.approve,
        isCurrent: () => true,
      ),
      throwsA(isA<VoucherApprovalChanged>()),
    );
    shown = await load(VoucherApprovalKind.credit, 1);
    h.ledgerFor(VoucherApprovalKind.credit, 1)[0]['vm_voucher_approved_flag'] =
        '1';
    await expectLater(
      h.approvals.submit(
        h.auth.session!,
        h.profile,
        shown,
        VoucherApprovalAction.approve,
        isCurrent: () => true,
      ),
      throwsA(isA<VoucherApprovalChanged>()),
    );
    expect(h.updates, isEmpty);
  });
  test(
    'already approved cannot be approved again by a retained action',
    () async {
      final shown = await load(VoucherApprovalKind.credit, 0);
      await expectLater(
        h.approvals.submit(
          h.auth.session!,
          h.profile,
          shown,
          VoucherApprovalAction.approve,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.updates, isEmpty);
    },
  );
  test(
    'unconfirmed POST has no automatic retry and success string is exact',
    () async {
      final shown = await load(VoucherApprovalKind.credit, 1);
      h.onApprovalPost =
          (_, _) async =>
              throw const AppFailure(
                'Synthetic network failure',
                kind: FailureKind.network,
              );
      await expectLater(
        h.approvals.submit(
          h.auth.session!,
          h.profile,
          shown,
          VoucherApprovalAction.approve,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.updates.length, 1);
      h.onApprovalPost = (_, _) async => {'string_out': 'successfully created'};
      await expectLater(
        h.approvals.submit(
          h.auth.session!,
          h.profile,
          shown,
          VoucherApprovalAction.approve,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.updates.length, 2);
    },
  );
  test('no write after cancellation while fresh ledger is loading', () async {
    final shown = await load(VoucherApprovalKind.credit, 1),
        pending = Completer<JsonMap>();
    var current = true;
    h.onApprovalGet = (_) async => pending.future;
    final submit = h.approvals.submit(
      h.auth.session!,
      h.profile,
      shown,
      VoucherApprovalAction.approve,
      isCurrent: () => current,
    );
    current = false;
    pending.complete(
      h.page([
        {'voucher_list': h.ledgerFor(VoucherApprovalKind.credit, 1)},
      ]),
    );
    await expectLater(submit, throwsA(isA<ObsoleteRequest>()));
    expect(h.updates, isEmpty);
  });
  test(
    'role, forced logout, expiry and module guards prevent ledger reads',
    () async {
      for (final patch in <JsonMap>[
        {'hr_acc_active_flag': '0'},
        {'acc_dashboard': '0'},
        {'usr_mob_forced_log_out_flag': '1'},
        {'usr_mob_app_access': '0'},
        {'exp_date': '01-JAN-20'},
      ]) {
        final original = Map<String, Object?>.of(h.adminData);
        h.adminData.addAll(patch);
        await expectLater(
          h.approvals.latest(
            h.auth.session!,
            h.profile,
            VoucherApprovalKind.credit,
            isCurrent: () => true,
          ),
          throwsA(anything),
        );
        h.adminData
          ..clear()
          ..addAll(original);
      }
      expect(h.approvalReads, isEmpty);
    },
  );
  test('header username cannot be missing or include line breaks', () async {
    final shown = await load(VoucherApprovalKind.credit, 1);
    for (final name in ['', 'unsafe\nvalue']) {
      h.adminData['usr_name'] = name;
      await expectLater(
        h.approvals.submit(
          h.auth.session!,
          h.profile,
          shown,
          VoucherApprovalAction.approve,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(h.updates, isEmpty);
  });
  test(
    'approval and report totals use lakh grouping without dropping decimal cents',
    () {
      expect(approvalAmount(VtMoney.parse('183000')), '1,83,000');
      expect(approvalAmount(VtMoney.parse('12345678.05')), '1,23,45,678.05');
      expect(approvalAmount(VtMoney.parse('-1234.50')), '-1,234.5');
      expect(approvalAmount(VtMoney.zero), '0');
    },
  );
}
