import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/app_toast.dart';
import '../../core/failure.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../appointments/doctor_schedule/progress/doctor_progress_models.dart';
import '../appointments/doctor_schedule/progress/doctor_progress_repository.dart';
import '../appointments/doctor_schedule/progress/doctor_progress_screen.dart';
import '../dashboard/dashboard_navigation.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import '../dynamic_prescription/dynamic_prescription_repository.dart';
import '../dynamic_prescription/dynamic_prescription_preview_repository.dart';
import '../dynamic_prescription/native_dynamic_preview_platform.dart';
import '../dynamic_prescription/native_dynamic_preview_screen.dart';
import '../dynamic_prescription/native_dynamic_rx_controls.dart';
import '../prescription/normal_prescription_models.dart';
import '../prescription/normal_prescription_repository.dart';
import '../prescription/normal_prescription_screen.dart';
import 'native_patient_prescription_history_sheet.dart';
import 'native_patient_search_layout.dart';
import 'native_patient_search_year_dialog.dart';
import 'patient_appointment_calendar_screen.dart';
import 'patient_search_models.dart';
import 'patient_search_repository.dart';

class PatientSearchScreen extends StatefulWidget {
  const PatientSearchScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.destinationBuilder,
    this.previewPlatform,
  });
  final AuthController auth;
  final PatientSearchRepository repository;
  final DashboardDestinationBuilder? destinationBuilder;
  final DynamicPreviewPlatform? previewPlatform;
  @override
  State<PatientSearchScreen> createState() => _PatientSearchState();
}

class _PatientSearchState extends State<PatientSearchScreen>
    with WidgetsBindingObserver {
  late final AuthSession? _session = widget.auth.session;
  final _dialogs = NativeDashboardDialogOwner();
  final _toast = AppToastOwner();
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  AccountProfile? _profile;
  List<PatientSearchRow> _rows = const [];
  late int _year = widget.repository.now().year;
  late PatientSearchMode _mode =
      widget.auth.profile == null
          ? PatientSearchMode.normal
          : PatientSearchMode.forProfile(widget.auth.profile!);
  String? _committedSearch, _error;
  String _helper = patientSearchRecentMessage;
  bool _helperError = false,
      _busy = true,
      _opening = false,
      _checking = false,
      _away = false,
      _foreground = true,
      _needsRefresh = false;
  int _operation = 0;
  ModalBottomSheetRoute<String>? _sheet;
  NavigatorState? _sheetNavigator;
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
      !_opening &&
      _error == null &&
      !_dialogs.isOpen &&
      _sheet == null;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) unawaited(_load());
    });
  }

  void _closeSheet() {
    final route = _sheet, navigator = _sheetNavigator;
    _sheet = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator != null &&
          navigator.mounted &&
          route != null &&
          route.isActive) {
        navigator.removeRoute(route);
      }
    });
  }

  void _authChanged() {
    if (_current) return;
    ++_operation;
    _dialogs.close();
    _closeSheet();
    _toast.clear();
    _search.clear();
    _focus.unfocus();
    if (mounted) {
      setState(() {
        _rows = const [];
        _profile = null;
        _busy = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _needsRefresh = true;
      ++_operation;
      _focus.unfocus();
      _closeSheet();
      _toast.clear();
      if (!_away) _dialogs.close();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && !_foreground) {
      _foreground = true;
      if (!_away && _current) {
        unawaited(_load(query: _committedSearch, preserve: true));
      }
    }
  }

  String _scope(AccountProfile p) => [
    p.doctorId,
    PatientSearchMode.forProfile(p).name,
    p.value('all_presc'),
    p.value('doc_head_flag'),
    p.value('deptd_id'),
  ].join('|');

  void _failure(Object failure) {
    if (failure is AppFailure && failure.kind == FailureKind.denied) {
      widget.auth.blockAccess(
        failure is AccountAccessFailure
            ? failure
            : const AccountAccessFailure.mobileAccess(),
      );
    }
  }

  Future<AccountProfile> _fresh(int op) async {
    final profile = await widget.auth.profiles.open(
      _session!,
      recordLogin: false,
      isCurrent: () => _alive(op),
    );
    widget.repository.guard(_session, profile, () => _alive(op));
    return profile;
  }

  Future<void> _load({String? query, bool preserve = false}) async {
    if (!_current || !_foreground || _away) return;
    final op = ++_operation;
    _committedSearch = query;
    _needsRefresh = false;
    setState(() {
      _busy = true;
      _error = null;
      _helperError = false;
      if (!preserve) _rows = const [];
    });
    try {
      final profile = await _fresh(op),
          mode = PatientSearchMode.forProfile(profile);
      final changedScope =
          _profile != null && _scope(_profile!) != _scope(profile);
      if (changedScope) {
        _search.clear();
        _committedSearch = null;
        _rows = const [];
      }
      if (mode == PatientSearchMode.normal) _committedSearch = null;
      final rows = await widget.repository.patients(
        _session!,
        profile,
        _year,
        search: _committedSearch,
        isCurrent: () => _alive(op),
      );
      if (!_alive(op)) return;
      setState(() {
        _profile = profile;
        _mode = mode;
        _rows = rows;
        _busy = false;
        _helper =
            _committedSearch == null
                ? patientSearchRecentMessage
                : patientSearchResultsMessage;
      });
      if ((!preserve || changedScope) && _scroll.hasClients) _scroll.jumpTo(0);
    } catch (failure) {
      if (!_alive(op) || failure is ObsoleteRequest) return;
      _failure(failure);
      if (!mounted || !_current) return;
      setState(() {
        _busy = false;
        _rows = const [];
        _error = dashboardErrorMessage(failure);
      });
      final retry = await _dialogs.show<bool>(
        context,
        AlertDialog(
          key: const Key('patient_search_error_dialog'),
          title: const Text('Error!'),
          content: Text(_error!),
          actions: [
            TextButton(
              key: const Key('patient_search_error_exit'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('EXIT'),
            ),
            TextButton(
              key: const Key('patient_search_error_retry'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
      if (!_alive(op)) return;
      if (retry == true) {
        await _load(query: _committedSearch);
      } else if (retry == false && mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _pickYear() async {
    if (!_ready) return;
    _focus.unfocus();
    final year = await _dialogs.show<int>(
      context,
      NativePatientSearchYearDialog(
        selected: _year,
        now: widget.repository.now(),
      ),
      dismissible: true,
    );
    if (year == null || !_current || !_foreground) return;
    setState(() {
      _year = year;
      _search.clear();
    });
    await _load();
  }

  Future<void> _searchRemote() async {
    if (!_ready) return;
    final query = _search.text.trim(),
        error = patientSearchQueryError(_search.text);
    if (error != null) {
      setState(() {
        _helper = error;
        _helperError = true;
      });
      return;
    }
    _focus.unfocus();
    await _load(query: query);
  }

  Future<void> _push(DashboardRoute route, Widget fallback) async {
    if (!_current || !_foreground) return;
    await _dialogs.push<void>(
      context,
      widget.destinationBuilder?.call(context, route) ?? fallback,
    );
  }

  Future<void> _open(PatientSearchRow patient, String action) async {
    if (!_ready || !_rows.contains(patient)) return;
    _focus.unfocus();
    setState(() {
      _opening = true;
      _checking = true;
      _away = true;
    });
    final op = ++_operation;
    try {
      final profile = await _fresh(op);
      if (!mounted || !_alive(op)) return;
      setState(() => _checking = false);
      if (_profile == null || _scope(profile) != _scope(_profile!)) {
        _needsRefresh = true;
        return;
      }
      final extras = {
        'P_NAME': patient.name,
        'P_CODE': patient.code,
        'P_PH_ID': patient.historyId,
      };
      if (action == 'progress') {
        if (patient.progress <= 0) return;
        await _push(
          DashboardRoute(
            DashboardModule.doctorHealthProgress,
            extras: {...extras, 'FROM_PSV': 'true'},
          ),
          DoctorProgressScreen(
            auth: widget.auth,
            repository: DoctorProgressRepository(
              widget.repository.appointments,
            ),
            seed: DoctorProgressSeed.viewPatient(
              patientId: patient.historyId,
              patientName: patient.name,
              patientCode: patient.code,
            ),
          ),
        );
      } else if (action == 'appointments') {
        await _push(
          DashboardRoute(
            DashboardModule.patientAppointmentCalendar,
            extras: extras,
          ),
          PatientAppointmentCalendarScreen(
            auth: widget.auth,
            repository: widget.repository,
            patient: patient,
          ),
        );
      } else if (_mode == PatientSearchMode.normal) {
        await _push(
          DashboardRoute(
            DashboardModule.doctorLegacyPrescription,
            extras: {'P_PH_ID': patient.historyId, 'FROM_PSV': 'true'},
          ),
          NormalPrescriptionScreen(
            auth: widget.auth,
            repository: NormalPrescriptionRepository(
              widget.repository.appointments,
            ),
            seed: NormalPrescriptionSeed.patient(patient.values),
          ),
        );
      } else {
        final navigator = Navigator.of(context);
        final sheet = ModalBottomSheetRoute<String>(
          isScrollControlled: true,
          useSafeArea: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          capturedThemes: InheritedTheme.capture(
            from: context,
            to: navigator.context,
          ),
          builder:
              (_) => NativePatientPrescriptionHistorySheet(
                load: () async {
                  final fresh = await _fresh(op);
                  if (_scope(fresh) != _scope(profile)) {
                    _needsRefresh = true;
                    throw const AppFailure(
                      'Patient access changed. Close this sheet and search again.',
                    );
                  }
                  return widget.repository.history(
                    _session!,
                    fresh,
                    patient,
                    isCurrent: () => _alive(op),
                  );
                },
                onFailure: _failure,
              ),
        );
        _sheet = sheet;
        _sheetNavigator = navigator;
        final id = await navigator.push(sheet);
        if (_sheet == sheet) _sheet = null;
        if (id == null || !_alive(op)) return;
        await _push(
          DashboardRoute(
            DashboardModule.doctorPrescriptionPreview,
            extras: {'RVM_ID': id},
          ),
          NativeDynamicPreviewScreen(
            auth: widget.auth,
            repository: DynamicPrescriptionPreviewRepository(
              DynamicPrescriptionRepository(widget.repository.appointments),
            ),
            rvmId: id,
            platform: widget.previewPlatform,
          ),
        );
      }
    } catch (failure) {
      if (!_alive(op) || failure is ObsoleteRequest) return;
      _failure(failure);
      if (mounted && _current) {
        await _dialogs.show<void>(
          context,
          NativeDashboardMessageDialog(
            title: 'Error!',
            message: dashboardErrorMessage(failure),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _opening = false;
          _checking = false;
          _away = false;
        });
      }
      if (_current && _foreground && _needsRefresh) {
        unawaited(_load(query: _committedSearch, preserve: true));
      }
    }
  }

  @override
  void dispose() {
    ++_operation;
    widget.auth.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    _closeSheet();
    _dialogs.dispose();
    _toast.dispose();
    _search.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context),
        dynamicMode = _mode == PatientSearchMode.dynamicPrescription;
    final rows =
        dynamicMode
            ? _rows
            : _rows.where((p) => p.matches(_search.text)).toList();
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(dynamicMode ? m.d(8) : 10),
      borderSide: const BorderSide(color: DocColors.primary),
    );
    return PopScope(
      canPop: !_busy && !_opening,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop &&
            (_busy || _opening) &&
            _sheet == null &&
            !_dialogs.isOpen) {
          _toast.show(context, 'Please wait while loading');
        }
      },
      child: NativePatientSearchShell(
        compactHeader: dynamicMode,
        onBack: !_busy && !_opening ? () => Navigator.pop(context) : null,
        child: Stack(
          children: [
            Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(m.d(8), 10, m.d(8), 7),
                    child: InkWell(
                      key: Key(
                        dynamicMode
                            ? 'patient_search_year'
                            : 'normal_patient_year',
                      ),
                      onTap: _ready ? _pickYear : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${dynamicMode ? 'Search Year' : 'Year'}: $_year',
                            style: m.text(
                              12,
                              weight: FontWeight.w700,
                              color: DocColors.greenSea,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: DocColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(m.d(4)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          elevation: 1.5,
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            dynamicMode ? m.d(8) : 10,
                          ),
                          child: TextField(
                            key: Key(
                              dynamicMode
                                  ? 'patient_search_query'
                                  : 'normal_patient_search',
                            ),
                            controller: _search,
                            focusNode: _focus,
                            enabled:
                                !_busy && !_opening && _current && _foreground,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
                            style: m.text(
                              10,
                              color: patientSearchText,
                              weight: FontWeight.w700,
                            ),
                            autocorrect: false,
                            enableSuggestions: false,
                            smartDashesType: SmartDashesType.disabled,
                            smartQuotesType: SmartQuotesType.disabled,
                            textCapitalization: TextCapitalization.none,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              labelText:
                                  dynamicMode
                                      ? 'Search by Name, Code or mobile'
                                      : 'Search Patient (Name or Code)',
                              labelStyle: m.text(
                                10,
                                color: const Color(0xffb2bec3),
                                weight: FontWeight.w600,
                              ),
                              floatingLabelStyle:
                                  WidgetStateTextStyle.resolveWith((states) {
                                    if (states.contains(WidgetState.focused)) {
                                      return m.text(
                                        11,
                                        color: DocColors.primary,
                                      );
                                    }
                                    return m.text(
                                      11,
                                      color: const Color(0xff666666),
                                    );
                                  }),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: m.d(12),
                                vertical: m.d(14),
                              ),
                              border: outline,
                              enabledBorder: outline,
                              focusedBorder: outline,
                              disabledBorder: outline,
                              prefixIcon:
                                  dynamicMode
                                      ? null
                                      : const Icon(
                                        Icons.search,
                                        color: Color(0xff424242),
                                      ),
                              suffixIcon:
                                  dynamicMode && _search.text.isNotEmpty
                                      ? IconButton(
                                        key: const Key('patient_search_clear'),
                                        tooltip: 'Clear text',
                                        onPressed: () {
                                          _search.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.close),
                                      )
                                      : null,
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _focus.unfocus(),
                          ),
                        ),
                      ),
                      if (dynamicMode) ...[
                        SizedBox(width: m.d(8)),
                        SizedBox(
                          width: m.d(44),
                          height: m.d(44),
                          child: ElevatedButton(
                            key: const Key('patient_search_submit'),
                            onPressed: _ready ? _searchRemote : null,
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: EdgeInsets.zero,
                              backgroundColor: DocColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 1.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(m.d(8)),
                              ),
                            ),
                            child: const Icon(Icons.search, size: 24),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (dynamicMode)
                  Padding(
                    padding: EdgeInsets.fromLTRB(m.d(4), m.d(6), m.d(4), 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _helper,
                        key: const Key('patient_search_helper'),
                        style: m.text(
                          8,
                          color:
                              _helperError
                                  ? const Color(0xffc23616)
                                  : const Color(0xff667085),
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: m.d(8)),
                Expanded(
                  child:
                      _error != null
                          ? Center(
                            child: Text(_error!, textAlign: TextAlign.center),
                          )
                          : rows.isEmpty
                          ? Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: m.d(4)),
                              child:
                                  _busy
                                      ? const SizedBox.shrink()
                                      : Text(
                                        "No Patient's Prescription Found",
                                        style: m.text(
                                          12,
                                          color: const Color(0xff757575),
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                            ),
                          )
                          : ListView.builder(
                            key: const Key('patient_search_list'),
                            controller: _scroll,
                            padding: EdgeInsets.symmetric(horizontal: m.d(4)),
                            itemCount: rows.length,
                            itemBuilder:
                                (_, i) => NativePatientSearchCard(
                                  patient: rows[i],
                                  dynamicMode: dynamicMode,
                                  onPrescription:
                                      _ready
                                          ? () => unawaited(
                                            _open(rows[i], 'prescription'),
                                          )
                                          : null,
                                  onProgress:
                                      _ready
                                          ? () => unawaited(
                                            _open(rows[i], 'progress'),
                                          )
                                          : null,
                                  onAppointments:
                                      _ready
                                          ? () => unawaited(
                                            _open(rows[i], 'appointments'),
                                          )
                                          : null,
                                ),
                          ),
                ),
              ],
            ),
            if (_busy || _checking)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x99ffffff),
                  child: Center(
                    child: CircularProgressIndicator(
                      key: Key('patient_search_loading'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
