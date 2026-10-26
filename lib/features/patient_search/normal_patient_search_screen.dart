import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import '../prescription/normal_prescription_models.dart';
import '../prescription/normal_prescription_repository.dart';
import '../prescription/normal_prescription_screen.dart';
import '../prescription/native_normal_prescription_layout.dart';

class NormalPatientSearchScreen extends StatefulWidget {
  const NormalPatientSearchScreen({
    super.key,
    required this.auth,
    required this.repository,
  });
  final AuthController auth;
  final NormalPrescriptionRepository repository;
  @override
  State<NormalPatientSearchScreen> createState() =>
      _NormalPatientSearchScreenState();
}

class _NormalPatientSearchScreenState extends State<NormalPatientSearchScreen>
    with WidgetsBindingObserver {
  AuthSession? _session;
  final _dialogs = NativeDashboardDialogOwner();
  final _search = TextEditingController();
  List<JsonMap> _rows = [];
  bool _busy = true, _foreground = true, _away = false;
  String? _error;
  late int _year;
  int _operation = 0;
  bool get _current =>
      mounted &&
      _session != null &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool _alive(int op) => _current && _foreground && op == _operation;
  @override
  void initState() {
    super.initState();
    _session = widget.auth.session;
    _year = widget.repository.now().year;
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) unawaited(_load());
    });
  }

  void _authChanged() {
    if (!_current) {
      ++_operation;
      _dialogs.close();
      _search.clear();
      if (mounted) setState(() => _rows = []);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _foreground = false;
      ++_operation;
      if (!_away) _dialogs.close();
    } else if (!_foreground) {
      _foreground = true;
      if (!_away) unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (!_current || !_foreground || _away) return;
    final op = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
      _rows = [];
    });
    try {
      final p = await widget.auth.profiles.open(
        _session!,
        recordLogin: false,
        isCurrent: () => _alive(op),
      );
      final rows = await widget.repository.patients(
        _session!,
        p,
        _year,
        isCurrent: () => _alive(op),
      );
      if (_alive(op)) {
        setState(() {
          _rows = rows;
          _busy = false;
        });
      }
    } catch (f) {
      if (!_alive(op) || f is ObsoleteRequest) return;
      if (f is AppFailure && f.kind == FailureKind.denied) {
        widget.auth.blockAccess(
          f is AccountAccessFailure
              ? f
              : const AccountAccessFailure.mobileAccess(),
        );
        return;
      }
      setState(() {
        _busy = false;
        _error = dashboardErrorMessage(f);
      });
    }
  }

  Future<void> _open(JsonMap row) async {
    if (!_current || _busy || _away || _dialogs.isOpen) return;
    _away = true;
    try {
      await _dialogs.push<void>(
        context,
        NormalPrescriptionScreen(
          auth: widget.auth,
          repository: widget.repository,
          seed: NormalPrescriptionSeed.patient(row),
        ),
      );
    } finally {
      _away = false;
      if (_current && _foreground) await _load();
    }
  }

  Future<void> _pickYear() async {
    if (_busy || _away || !_current) return;
    final year = await _dialogs.show<int>(
      context,
      AlertDialog(
        title: const Text('Select Year'),
        content: SizedBox(
          width: 280,
          height: 350,
          child: ListView.builder(
            itemCount: widget.repository.now().year - 1949,
            itemBuilder: (context, index) {
              final year = widget.repository.now().year - index;
              return ListTile(
                title: Text('$year'),
                selected: year == _year,
                onTap: () => Navigator.pop(context, year),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
      dismissible: true,
    );
    if (year != null && _current && _foreground) {
      setState(() {
        _year = year;
        _search.clear();
      });
      await _load();
    }
  }

  @override
  void dispose() {
    ++_operation;
    widget.auth.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    _dialogs.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase();
    final matches =
        _rows
            .where(
              (r) =>
                  rxValue(r, 'pat_name').toLowerCase().contains(query) ||
                  rxValue(r, 'sub_code').toLowerCase().contains(query),
            )
            .toList();
    return NormalPrescriptionShell(
      title: 'Patient Search',
      onBack: () => Navigator.pop(context),
      waiting: _busy,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('normal_patient_year'),
                    onPressed: _pickYear,
                    child: Text('Year: $_year'),
                  ),
                ),
                TextField(
                  key: const Key('normal_patient_search'),
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Search by patient name or code',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          Expanded(
            child:
                matches.isEmpty
                    ? const Center(child: Text('No Patient Found'))
                    : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final row = matches[index];
                        return Card(
                          color: DocColors.clouds,
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: DocColors.primary),
                          ),
                          child: ListTile(
                            key: Key('normal_patient_${rxValue(row, "ph_id")}'),
                            onTap: () => unawaited(_open(row)),
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              rxValue(row, 'pat_name'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${rxValue(row, "sub_code")}\n${rxValue(row, "gender")}  ${rxValue(row, "pat_age")}\n${rxValue(row, "dd_thana_name")}',
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: DocColors.greenSea,
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
