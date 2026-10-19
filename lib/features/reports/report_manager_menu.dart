/// ReportManager.java passes these exact R_TYPE values to ReportView.
enum ReportManagerItem {
  paymentReceive('1', 'Payment Receive Report'),
  paymentRegister('5', 'Payment Receive Register Report'),
  paymentSummary('2', 'Payment Receive Summary Report'),
  doctorPayment('3', 'Doctor Wise Payment Receive Report'),
  doctorAppointment('4', 'Doctor Wise Appointment Report');

  const ReportManagerItem(this.nativeType, this.title);

  final String nativeType;
  final String title;
}

/// Preserve the native case-sensitive check of the selected centre API URL.
/// The register entry is second when present; all other entries keep their order.
List<ReportManagerItem> nativeReportManagerItems(Uri centerApi) {
  final api = centerApi.toString();
  return List.unmodifiable([
    ReportManagerItem.paymentReceive,
    if (api.contains('cstar') || api.contains('btrf'))
      ReportManagerItem.paymentRegister,
    ReportManagerItem.paymentSummary,
    ReportManagerItem.doctorPayment,
    ReportManagerItem.doctorAppointment,
  ]);
}
