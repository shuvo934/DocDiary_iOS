import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_toast.dart';
import '../../core/app_theme.dart';
import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../../core/native_json.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import 'normal_prescription_models.dart';
import 'normal_prescription_native_style.dart';
import 'normal_prescription_repository.dart';
import 'native_normal_prescription_layout.dart';

class NormalPrescriptionScreen extends StatefulWidget {
  const NormalPrescriptionScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.seed,
  });
  final AuthController auth;
  final NormalPrescriptionRepository repository;
  final NormalPrescriptionSeed seed;
  @override
  State<NormalPrescriptionScreen> createState() =>
      _NormalPrescriptionScreenState();
}

class _NormalPrescriptionScreenState extends State<NormalPrescriptionScreen>
    with WidgetsBindingObserver {
  AuthSession? _session;
  final _dialogs = NativeDashboardDialogOwner(), _toasts = AppToastOwner();
  NormalPrescriptionSnapshot? _snapshot;
  final _rows = <NormalPrescriptionSection, List<JsonMap>>{};
  JsonMap? _diagnosis, _referral, _existing;
  RxSectionSpec? _editing;
  RxContext? _editContext;
  final _values = <String, String>{},
      _controllers = <String, TextEditingController>{};
  final _choices = <String, List<RxChoice>>{};
  final _fieldErrors = <String, String>{};
  bool _busy = true,
      _writing = false,
      _foreground = true,
      _resumeAfterWrite = false,
      _unconfirmed = false,
      _reconcileDraft = false;
  int _operation = 0, _historyTab = 0, _treatmentTab = 0;
  String? _error;
  bool get _current =>
      mounted &&
      _session != null &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool _alive(int op) => _current && _foreground && op == _operation;
  bool get _ready =>
      _current &&
      _foreground &&
      !_busy &&
      !_writing &&
      !_unconfirmed &&
      _error == null &&
      !_dialogs.isOpen;
  RxContext get _context =>
      RxContext(_snapshot!.patient, diagnosis: _diagnosis, referral: _referral);
  @override
  void initState() {
    super.initState();
    _session = widget.auth.session;
    if (_session == null || !widget.seed.valid) {
      _busy = false;
      _error = 'Prescription details are unavailable.';
      return;
    }
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) unawaited(_load());
    });
  }

  void _authChanged() {
    if (!_current) {
      ++_operation;
      _dialogs.close();
      _toasts.clear();
      for (final c in _controllers.values) {
        c.clear();
      }
      if (mounted) {
        setState(() {
          _snapshot = null;
          _rows.clear();
          _editing = null;
          _busy = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _foreground = false;
      ++_operation;
      _dialogs.close();
      _toasts.clear();
      if (mounted) setState(() {});
    } else if (!_foreground) {
      _foreground = true;
      if (_writing) {
        _resumeAfterWrite = true;
      } else if (_current) {
        unawaited(_load());
      }
    }
  }

  Future<AccountProfile> _profile(int op) async {
    final p = await widget.auth.profiles.open(
      _session!,
      recordLogin: false,
      isCurrent: () => _alive(op),
    );
    widget.repository.guard(
      _session!,
      p,
      widget.seed,
      () => _alive(op),
      write: !widget.seed.readOnly,
    );
    return p;
  }

  bool _deny(Object failure) {
    if (failure is AppFailure && failure.kind == FailureKind.denied) {
      widget.auth.blockAccess(
        failure is AccountAccessFailure
            ? failure
            : const AccountAccessFailure.mobileAccess(),
      );
      return true;
    }
    return false;
  }

  Future<void> _load() async {
    if (!_current || !_foreground || _writing || _dialogs.isOpen) return;
    final op = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await _profile(op),
          data = await widget.repository.load(
            _session!,
            p,
            widget.seed,
            isCurrent: () => _alive(op),
          );
      if (!_alive(op)) return;
      final rows = Map<NormalPrescriptionSection, List<JsonMap>>.of(data.rows);
      final ds = rows[NormalPrescriptionSection.diagnosis] ?? [];
      JsonMap? selected(List<JsonMap> list, JsonMap? previous, String id) =>
          list.isEmpty
              ? null
              : list.firstWhere(
                (r) =>
                    previous != null && rxValue(previous, id) == rxValue(r, id),
                orElse: () => list.first,
              );
      final diagnosis = selected(ds, _diagnosis, 'pdi_id');
      JsonMap? referral;
      if (diagnosis != null) {
        final refs = await widget.repository.section(
          _session!,
          p,
          widget.seed,
          rxSectionSpecs[NormalPrescriptionSection.referral]!,
          RxContext(data.patient, diagnosis: diagnosis),
          isCurrent: () => _alive(op),
        );
        rows[NormalPrescriptionSection.referral] = refs;
        referral = selected(refs, _referral, 'drd_id');
        if (referral != null) {
          rows[NormalPrescriptionSection
              .service] = await widget.repository.section(
            _session!,
            p,
            widget.seed,
            rxSectionSpecs[NormalPrescriptionSection.service]!,
            RxContext(data.patient, diagnosis: diagnosis, referral: referral),
            isCurrent: () => _alive(op),
          );
        }
      }
      if (!_alive(op)) return;
      setState(() {
        _snapshot = data;
        _rows
          ..clear()
          ..addAll(rows);
        _diagnosis = diagnosis;
        _referral = referral;
        _busy = false;
        _unconfirmed = false;
      });
      if (_editing != null && _reconcileDraft) {
        _reconcileDraft = false;
        final entries = _rows[_editing!.section] ?? [];
        if (_editContext!.parentId(_editing!) == _context.parentId(_editing!) &&
            entries.any(
              (r) => _editing!.fields.every(
                (f) => rxValue(r, f.rowKey) == (_values[f.header] ?? ''),
              ),
            )) {
          setState(() => _editing = null);
          if (mounted) _toasts.show(context, 'Prescription data is saved.');
        }
      }
    } catch (f) {
      if (!_alive(op) || f is ObsoleteRequest || _deny(f)) return;
      setState(() {
        _busy = false;
        _error = dashboardErrorMessage(f);
        if (_editing == null) {
          _snapshot = null;
          _rows.clear();
        }
      });
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final op = _operation;
    final result = await _dialogs.show<bool>(
      context,
      AlertDialog(
        title:
            title.isEmpty
                ? null
                : Text(
                  title,
                  style: rxNativeText(
                    20,
                    weight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
        content: Text(message, style: rxNativeText(16, color: Colors.black87)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'NO',
              style: rxNativeText(
                14,
                weight: FontWeight.w500,
                color: DocColors.primary,
              ),
            ),
          ),
          TextButton(
            key: const Key('rx_confirm_yes'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'YES',
              style: rxNativeText(
                14,
                weight: FontWeight.w500,
                color: DocColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
    return result == true && _alive(op);
  }

  Future<void> _write(
    String title,
    String message,
    Future<void> Function(AccountProfile, int) action,
  ) async {
    if (!_ready ||
        widget.seed.readOnly ||
        !await _confirm(title, message) ||
        !_ready) {
      return;
    }
    final op = ++_operation;
    setState(() {
      _busy = true;
      _writing = true;
      _reconcileDraft = _editing != null;
      _error = null;
    });
    try {
      final p = await _profile(op);
      await action(p, op);
      if (!_alive(op)) return;
      setState(() => _editing = null);
      if (mounted) _toasts.show(context, 'Prescription updated successfully.');
    } catch (f) {
      if (_alive(op) && f is! ObsoleteRequest && !_deny(f)) {
        setState(() {
          _error =
              '${dashboardFailureDetail(f)}\nReload saved data before trying again. Your draft is kept until then.';
          _unconfirmed = true;
        });
      }
    } finally {
      _writing = false;
      if (mounted) setState(() => _busy = false);
      if (_current && _foreground && (!_unconfirmed || _resumeAfterWrite)) {
        _resumeAfterWrite = false;
        await _load();
      }
    }
  }

  Future<void> _create() => _write(
    'Create Prescription!',
    'Do you want to create prescription for this patient?',
    (p, op) => widget.repository.create(
      _session!,
      p,
      widget.seed,
      isCurrent: () => _alive(op),
    ),
  );
  Future<void> _select(NormalPrescriptionSection kind, JsonMap row) async {
    if (!_ready) return;
    final op = ++_operation;
    setState(() => _busy = true);
    try {
      final p = await _profile(op);
      if (kind == NormalPrescriptionSection.diagnosis) {
        final refs = await widget.repository.section(
          _session!,
          p,
          widget.seed,
          rxSectionSpecs[NormalPrescriptionSection.referral]!,
          RxContext(_snapshot!.patient, diagnosis: row),
          isCurrent: () => _alive(op),
        );
        if (!_alive(op)) return;
        setState(() {
          _diagnosis = row;
          _referral = null;
          _rows[NormalPrescriptionSection.referral] = refs;
          _rows[NormalPrescriptionSection.service] = [];
        });
        if (refs.isNotEmpty) {
          final services = await widget.repository.section(
            _session!,
            p,
            widget.seed,
            rxSectionSpecs[NormalPrescriptionSection.service]!,
            RxContext(_snapshot!.patient, diagnosis: row, referral: refs.first),
            isCurrent: () => _alive(op),
          );
          if (!_alive(op)) return;
          setState(() {
            _referral = refs.first;
            _rows[NormalPrescriptionSection.service] = services;
          });
        }
      } else {
        final services = await widget.repository.section(
          _session!,
          p,
          widget.seed,
          rxSectionSpecs[NormalPrescriptionSection.service]!,
          RxContext(_snapshot!.patient, diagnosis: _diagnosis, referral: row),
          isCurrent: () => _alive(op),
        );
        if (!_alive(op)) return;
        setState(() {
          _referral = row;
          _rows[NormalPrescriptionSection.service] = services;
        });
      }
    } catch (f) {
      if (_alive(op) && f is! ObsoleteRequest && !_deny(f)) {
        setState(() {
          _error = dashboardErrorMessage(f);
          _snapshot = null;
          _rows.clear();
        });
      }
    } finally {
      if (_alive(op)) setState(() => _busy = false);
    }
  }

  Future<void> _edit(NormalPrescriptionSection kind, JsonMap? existing) async {
    if (!_ready || widget.seed.readOnly || _snapshot == null) return;
    final spec = rxSectionSpecs[kind]!;
    if (existing != null && !rxMayModify(spec, existing)) return;
    _values
      ..clear()
      ..addAll(
        existing == null
            ? {for (final f in spec.fields) f.header: ''}
            : spec.values(existing),
      );
    for (final f in spec.fields) {
      final c = _controllers.putIfAbsent(
        f.header,
        () => TextEditingController(),
      );
      c.text = existing == null ? '' : f.display(existing);
    }
    _existing = existing;
    _fieldErrors.clear();
    _editContext = _context;
    setState(() => _editing = spec);
    await _loadChoices();
  }

  Future<void> _loadChoices() async {
    if (!_current || !_foreground || _editing == null) return;
    final op = ++_operation;
    setState(() => _busy = true);
    try {
      final p = await _profile(op);
      final spec = _editing!;
      final result = <String, List<RxChoice>>{};
      for (final f in spec.fields) {
        if (f.lookup.isNotEmpty) {
          result[f.header] = await widget.repository.choices(
            _session!,
            p,
            widget.seed,
            spec,
            _editContext!,
            f,
            departmentId: _values['P_DEPTS_ID'] ?? '',
            isCurrent: () => _alive(op),
          );
        }
      }
      if (!_alive(op)) return;
      setState(() {
        _choices
          ..clear()
          ..addAll(result);
        _error = null;
      });
    } catch (f) {
      if (_alive(op) && f is! ObsoleteRequest && !_deny(f)) {
        setState(() => _error = dashboardErrorMessage(f));
      }
    } finally {
      if (_alive(op)) setState(() => _busy = false);
    }
  }

  Future<void> _pick(RxField field) async {
    if (!_ready) return;
    final op = _operation;
    if (field.isDate) {
      final today = dateOnly(widget.repository.now());
      DateTime initial = today;
      try {
        initial = parseOracleDate(_values[field.header] ?? '');
      } on AppFailure {
        /* Use today's date for a new entry. */
      }
      if (initial.isAfter(today) || initial.isBefore(DateTime(1900))) {
        initial = today;
      }
      final date = await _dialogs.show<DateTime>(
        context,
        DatePickerDialog(
          initialDate: initial,
          firstDate: DateTime(1900),
          lastDate: today,
        ),
      );
      if (date != null && _alive(op)) {
        setState(() {
          _values[field.header] = oracleDate(date);
          _controllers[field.header]!.text = oracleDate(date);
        });
      }
      return;
    }
  }

  Future<void> _choose(RxField field, RxChoice choice) async {
    if (!_ready) return;
    setState(() {
      _values[field.header] = choice.id;
      _controllers[field.header]!.text = choice.name;
      _fieldErrors.remove(field.header);
      if (field.header == 'P_DEPTS_ID') {
        _values['P_DOC_ID'] = '';
        _controllers['P_DOC_ID']?.clear();
      }
    });
    if (field.header == 'P_DEPTS_ID') await _loadChoices();
  }

  void _fieldChanged(RxField field, String text) {
    _values[field.header] = field.isChoice ? '' : text;
    if (_fieldErrors.containsKey(field.header)) {
      setState(() => _fieldErrors.remove(field.header));
    }
    if (field.header == 'P_DEPTS_ID') {
      _values['P_DOC_ID'] = '';
      _controllers['P_DOC_ID']?.clear();
    }
  }

  Map<String, List<RxChoice>> _editorChoices(RxSectionSpec spec) => {
    for (final field in spec.fields)
      field.header: [
        if (field.isChoice &&
            (_values[field.header] ?? '').isNotEmpty &&
            !(_choices[field.header] ?? []).any(
              (c) => c.id == _values[field.header],
            ))
          RxChoice(_values[field.header]!, _controllers[field.header]!.text),
        ...?_choices[field.header],
      ],
  };

  Future<void> _submit() async {
    if (!_ready || _editing == null) return;
    final spec = _editing!;
    final invalidOptional = spec.fields.where(
      (f) =>
          f.isChoice &&
          !f.required &&
          _controllers[f.header]!.text.trim().isNotEmpty &&
          (_values[f.header] ?? '').isEmpty,
    );
    final error =
        invalidOptional.isNotEmpty
            ? 'Invalid Doctor Name'
            : rxDraftError(spec, _values);
    if (error != null) {
      setState(() {
        _fieldErrors.clear();
        if (invalidOptional.isNotEmpty) {
          _fieldErrors[invalidOptional.first.header] = 'Invalid Doctor Name';
        }
        for (final field in spec.fields) {
          if (field.required && (_values[field.header] ?? '').trim().isEmpty) {
            _fieldErrors[field.header] =
                field.isDate
                    ? 'Please Provide Injury Date'
                    : rxNativeMissing(spec, field);
          }
        }
      });
      _toasts.show(context, error);
      return;
    }
    await _write(
      _existing == null
          ? 'Add ${rxNativeName(spec.section)}!'
          : 'Update ${rxNativeName(spec.section)}!',
      _existing == null
          ? "Do you want to add patient's new ${spec.section == NormalPrescriptionSection.complain ? 'complain' : rxNativeName(spec.section)}?"
          : 'Do you want to update this ${spec.section == NormalPrescriptionSection.complain ? 'complain' : rxNativeName(spec.section)}?',
      (p, op) => widget.repository.save(
        _session!,
        p,
        widget.seed,
        spec,
        _editContext!,
        Map.of(_values),
        existing: _existing,
        isCurrent: () => _alive(op),
      ),
    );
  }

  Future<void> _delete(NormalPrescriptionSection kind, JsonMap row) async {
    final spec = rxSectionSpecs[kind]!;
    if (!rxMayModify(spec, row)) return;
    await _write(
      spec.section == NormalPrescriptionSection.diagnosis ||
              spec.section == NormalPrescriptionSection.referral
          ? ''
          : spec.fields.first.display(row),
      'Do you want to delete this ${rxNativeName(spec.section)}?',
      (p, op) => widget.repository.save(
        _session!,
        p,
        widget.seed,
        spec,
        _editing != null ? _editContext! : _context,
        {},
        existing: row,
        deleting: true,
        isCurrent: () => _alive(op),
      ),
    );
  }

  Future<void> _changeAdmission(bool value) => _write(
    'Patient Admission',
    'Update the patient admission setting?',
    (p, op) => widget.repository.admission(
      _session!,
      p,
      widget.seed,
      _context,
      value,
      isCurrent: () => _alive(op),
    ),
  );

  Future<void> _back() async {
    if (_writing || _dialogs.isOpen) return;
    if (_editing != null) {
      if (!_foreground ||
          !await _confirm(
            'Discard changes?',
            'Leave this form without saving?',
          )) {
        return;
      }
      setState(() {
        _editing = null;
        _unconfirmed = false;
        _error = null;
      });
      await _load();
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    ++_operation;
    widget.auth.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    _dialogs.dispose();
    _toasts.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = _editing;
    Widget body =
        editor == null
            ? NativeNormalPrescriptionLayout(
              seed: widget.seed,
              snapshot: _snapshot,
              rows: _rows,
              enabled: _ready,
              message: _error,
              diagnosis: _diagnosis,
              referral: _referral,
              historyTab: _historyTab,
              treatmentTab: _treatmentTab,
              onCreate: _create,
              onReload: _load,
              onEdit: _edit,
              onDelete: _delete,
              onSelect: _select,
              onAdmission: _changeAdmission,
              onHistoryTab: (v) {
                if (_ready) setState(() => _historyTab = v);
              },
              onTreatmentTab: (v) {
                if (_ready) setState(() => _treatmentTab = v);
              },
            )
            : NativeNormalPrescriptionEditor(
              spec: editor,
              controllers: _controllers,
              choices: _editorChoices(editor),
              updating: _existing != null,
              errors: _fieldErrors,
              onDelete:
                  _existing != null &&
                          const [
                            NormalPrescriptionSection.diagnosis,
                            NormalPrescriptionSection.referral,
                          ].contains(editor.section)
                      ? () => unawaited(_delete(editor.section, _existing!))
                      : null,
              onChoice: (field, choice) => unawaited(_choose(field, choice)),
              onPick: _pick,
              enabled: _ready,
              onChanged: _fieldChanged,
              onSave: _submit,
              onCancel: _back,
            );
    if (_error != null && (_snapshot != null || editor != null)) {
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
          TextButton(
            key: const Key('rx_error_reload'),
            onPressed:
                _busy || _writing
                    ? null
                    : () async {
                      if (editor != null && !_unconfirmed) {
                        await _loadChoices();
                      } else {
                        await _load();
                      }
                    },
            child: Text(_unconfirmed ? 'Reload saved data' : 'Retry'),
          ),
          Expanded(child: body),
        ],
      );
    }
    return PopScope(
      canPop: !_writing && editor == null,
      onPopInvokedWithResult: (popped, result) {
        if (!popped) unawaited(_back());
      },
      child: NormalPrescriptionShell(
        title:
            editor == null
                ? 'Prescription'
                : '${_existing == null ? "Add" : "Update"} ${rxNativeName(editor.section)}',
        matchNative: true,
        isEditor: editor != null,
        onBack: _writing ? null : _back,
        waiting: _busy,
        child: body,
      ),
    );
  }
}
