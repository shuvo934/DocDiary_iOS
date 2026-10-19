import 'package:docdiary_ios/features/reports/report_manager_menu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'ordinary centres retain native report order and nonconsecutive IDs',
    () {
      final reports = nativeReportManagerItems(
        Uri.parse('https://example.invalid/ords/crp/'),
      );
      expect(reports.map((r) => r.nativeType), ['1', '2', '3', '4']);
      expect(reports.map((r) => r.title), [
        'Payment Receive Report',
        'Payment Receive Summary Report',
        'Doctor Wise Payment Receive Report',
        'Doctor Wise Appointment Report',
      ]);
    },
  );

  test('both native register centres place R_TYPE 5 second', () {
    for (final url in [
      'https://example.invalid/ords/cstar/',
      'https://btrf.example.invalid/ords/center/',
    ]) {
      expect(
        nativeReportManagerItems(Uri.parse(url)).map((r) => r.nativeType),
        ['1', '5', '2', '3', '4'],
      );
    }
  });

  test('visibility uses the native case-sensitive whole-API contains rule', () {
    expect(
      nativeReportManagerItems(
        Uri.parse('https://example.invalid/ords/CSTAR/'),
      ),
      isNot(contains(ReportManagerItem.paymentRegister)),
    );
    expect(
      nativeReportManagerItems(
        Uri.parse('https://example.invalid/ords/archive_cstar_old/'),
      ),
      contains(ReportManagerItem.paymentRegister),
    );
  });
}
