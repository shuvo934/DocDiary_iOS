import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/failure.dart';
import '../../core/native_json.dart';
import 'dynamic_clinical_models.dart';

/// PrescriptionPatientItem/Adapter: identify registrations by PH_ID.
class DynamicPatientItem {
  DynamicPatientItem.fromData(JsonMap row)
    : patientId = dynamicRxText(row['pat_id']),
      historyId = dynamicRxText(row['ph_id']),
      name = dynamicRxText(row['pat_name']),
      code = dynamicRxText(row['sub_code']),
      thana = dynamicRxText(row['dd_thana_name']),
      year = dynamicRxText(row['pyear']),
      mobile = dynamicRxText(row['pat_cell']),
      gender = dynamicRxText(row['gender']),
      age = dynamicRxText(row['pat_age']);
  final String patientId,
      historyId,
      name,
      code,
      thana,
      year,
      mobile,
      gender,
      age;
  bool get valid =>
      patientId.isNotEmpty && historyId.isNotEmpty && name.isNotEmpty;
  String get details =>
      [gender, age].where((value) => value.isNotEmpty).join(' • ');
}

class DynamicPatientSelection {
  const DynamicPatientSelection(this.patient, this.prescriptionType);
  final DynamicPatientItem patient;
  final String prescriptionType;
}

/// Sheet-owned native 500ms debounce. Invalidating before the delay prevents
/// a previous year/search response from restoring stale rows or selection.
class DynamicPatientController extends ChangeNotifier {
  DynamicPatientController({
    required this.currentYear,
    required this.loadRecent,
    required this.searchPatients,
    String prescriptionType = '2',
    this.onFailure,
  }) : year = '$currentYear',
       prescriptionType = prescriptionType == '1' ? '1' : '2';
  final int currentYear;
  final Future<List<DynamicPatientItem>> Function(String year) loadRecent;
  final Future<List<DynamicPatientItem>> Function(String query) searchPatients;
  final void Function(Object failure)? onFailure;
  String year, prescriptionType, query = '', error = '';
  List<DynamicPatientItem> items = const [];
  DynamicPatientItem? selected;
  bool loading = false, _disposed = false;
  Timer? _timer;
  int _version = 0;
  List<String> get years => [
    for (var y = currentYear; y >= currentYear - 50; y--) '$y',
  ];
  bool get yearEnabled => query.isEmpty;
  bool get canSelect => !loading && selected != null;
  String get helper =>
      query.isEmpty
          ? 'Showing the latest 100 patients for the selected year'
          : query.length < 3
          ? 'Enter at least 3 characters to search'
          : 'Searching all registered patients';
  String get emptyText =>
      error.isNotEmpty
          ? '$error\nTap to retry'
          : query.isNotEmpty && query.length < 3
          ? 'Enter at least 3 characters to search'
          : 'No patient found';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  int _invalidate() {
    _timer?.cancel();
    _timer = null;
    ++_version;
    selected = null;
    items = const [];
    error = '';
    loading = false;
    return _version;
  }

  Future<void> start() => _request(_invalidate());
  void setQuery(String value) {
    if (_disposed) return;
    query = value.trim();
    final version = _invalidate();
    _notify();
    if (query.isEmpty) {
      unawaited(_request(version));
    } else if (query.length >= 3) {
      _timer = Timer(
        const Duration(milliseconds: 500),
        () => unawaited(_request(version)),
      );
    }
  }

  void setYear(String value) {
    if (_disposed || !yearEnabled || !years.contains(value)) return;
    year = value;
    query = '';
    unawaited(_request(_invalidate()));
  }

  void setPrescriptionType(String value) {
    if (_disposed || !const ['1', '2'].contains(value)) return;
    prescriptionType = value;
    _notify();
  }

  void select(DynamicPatientItem item) {
    if (_disposed || loading || !items.contains(item)) return;
    selected = item;
    _notify();
  }

  Future<void> retry() async {
    if (_disposed || loading || query.isNotEmpty && query.length < 3) return;
    await _request(_invalidate());
  }

  Future<void> _request(int version) async {
    if (_disposed || version != _version) return;
    final search = query, registrationYear = year;
    loading = true;
    error = '';
    _notify();
    try {
      final values =
          await (search.isEmpty
              ? loadRecent(registrationYear)
              : searchPatients(search));
      if (_disposed || version != _version) return;
      items = List.unmodifiable(values);
    } catch (failure) {
      if (_disposed || version != _version) return;
      if (failure is! ObsoleteRequest) {
        error =
            failure is AppFailure
                ? failure.message
                : 'Server Problem or Internet Not Connected';
        onFailure?.call(failure);
      }
    } finally {
      if (!_disposed && version == _version) {
        loading = false;
        _notify();
      }
    }
  }

  void close({bool notify = true}) {
    if (_disposed) return;
    _invalidate();
    if (notify) _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    ++_version;
    super.dispose();
  }
}
