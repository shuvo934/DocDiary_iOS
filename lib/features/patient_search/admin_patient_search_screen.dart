import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'admin_patient_search_models.dart';
import 'admin_patient_search_repository.dart';
import 'native_patient_prescription_history_sheet.dart';
import 'native_patient_search_layout.dart';
import 'native_patient_search_year_dialog.dart';
import 'patient_appointment_calendar_screen.dart';
import 'patient_search_models.dart';

/// PatientSearchAdmin.java, reusing the accepted patient card and view screens.
class AdminPatientSearchScreen extends StatefulWidget {
  const AdminPatientSearchScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.destinationBuilder,
    this.previewPlatform,
    this.openPhone,
  });
  final AuthController auth;
  final AdminPatientSearchRepository repository;
  final DashboardDestinationBuilder? destinationBuilder;
  final DynamicPreviewPlatform? previewPlatform;
  final Future<bool> Function(Uri)? openPhone;
  @override
  State<AdminPatientSearchScreen> createState() => _AdminPatientSearchState();
}

class _AdminPatientSearchState extends State<AdminPatientSearchScreen>
    with WidgetsBindingObserver {
  late final AuthSession? _session = widget.auth.session;
  final _dialogs = NativeDashboardDialogOwner();
  final _toast = AppToastOwner();
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late int _year = widget.repository.now().year;
  AccountProfile? _profile;
  List<PatientSearchRow> _rows = const [], _recent = const [];
  String? _committedSearch, _error;
  String _helper = '';
  bool _busy = true,
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
        _rows = _recent = const [];
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
    _needsRefresh = false;
    _committedSearch = query;
    setState(() {
      _busy = true;
      _error = null;
      _helper = '';
      if (!preserve) _rows = const [];
    });
    try {
      final profile = await _fresh(op);
      final changedScope =
          _profile != null &&
          adminPatientSearchScope(_profile!) !=
              adminPatientSearchScope(profile);
      if (changedScope) {
        _search.clear();
        _committedSearch = null;
        _rows = _recent = const [];
      }
      final rows = await widget.repository.patients(
        _session!,
        profile,
        _year,
        search: _committedSearch,
        isCurrent: () => _alive(op),
      );
      if (!mounted || !_alive(op)) return;
      setState(() {
        _profile = profile;
        _rows = rows;
        if (_committedSearch == null) _recent = rows;
        _busy = false;
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
          key: const Key('admin_patient_search_error_dialog'),
          title: Text(
            'Error!',
            style: dashboardDialogText(20, weight: FontWeight.w500),
          ),
          content: Text(_error!, style: dashboardDialogText(16)),
          actions: [
            TextButton(
              key: const Key('admin_patient_search_error_exit'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'EXIT',
                style: dashboardDialogText(
                  14,
                  color: DocColors.primary,
                  weight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              key: const Key('admin_patient_search_error_retry'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'RETRY',
                style: dashboardDialogText(
                  14,
                  color: DocColors.primary,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
      if (!mounted || !_alive(op)) return;
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
      _recent = const [];
    });
    await _load();
  }

  Future<void> _searchRemote() async {
    if (!_ready) return;
    final error = adminPatientSearchError(_search.text);
    if (error != null) {
      setState(() => _helper = error);
      _toast.show(context, error);
      return;
    }
    _focus.unfocus();
    await _load(query: _search.text);
  }

  Future<void> _clear() async {
    if (!_ready) return;
    _focus.unfocus();
    setState(() {
      _opening = _checking = true;
    });
    final op = ++_operation;
    try {
      final profile = await _fresh(op);
      if (!mounted || !_alive(op)) return;
      if (_needsRefresh ||
          _profile == null ||
          adminPatientSearchScope(profile) !=
              adminPatientSearchScope(_profile!)) {
        _needsRefresh = true;
        return;
      }
      setState(() {
        _search.clear();
        _helper = '';
        _committedSearch = null;
        _rows = _recent;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (failure) {
      if (_alive(op) && failure is! ObsoleteRequest) {
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
      }
    } finally {
      if (mounted) {
        setState(() {
          _opening = _checking = false;
        });
      }
      if (_current && _foreground && _needsRefresh) unawaited(_load());
    }
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
      _opening = _checking = _away = true;
    });
    final op = ++_operation;
    try {
      final profile = await _fresh(op);
      if (!mounted || !_alive(op)) return;
      setState(() => _checking = false);
      if (_profile == null ||
          adminPatientSearchScope(profile) !=
              adminPatientSearchScope(_profile!)) {
        _needsRefresh = true;
        return;
      }
      if (action == 'prescription' && patient.id.isEmpty) {
        throw const AppFailure(
          'Select a patient before viewing prescription history.',
        );
      }
      final extras = {
        'P_NAME': patient.name,
        'P_CODE': patient.code,
        'P_PH_ID': patient.historyId,
      };
      if (action == 'call') {
        if (!adminPatientMayCall(profile, patient)) return;
        final yes = await _dialogs.show<bool>(
          context,
          AlertDialog(
            key: const Key('admin_patient_call_dialog'),
            content: Text(
              'Do you want to make a call to ${patient.name} ?',
              style: dashboardDialogText(16),
            ),
            actions: [
              TextButton(
                key: const Key('admin_patient_call_no'),
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'NO',
                  style: dashboardDialogText(
                    14,
                    color: DocColors.primary,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                key: const Key('admin_patient_call_yes'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'YES',
                  style: dashboardDialogText(
                    14,
                    color: DocColors.primary,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
        if (!mounted || yes != true || !_alive(op)) return;
        final fresh = await _fresh(op);
        if (!mounted || !_alive(op)) return;
        if (!adminPatientMayCall(fresh, patient) ||
            adminPatientSearchScope(fresh) !=
                adminPatientSearchScope(profile)) {
          _needsRefresh = true;
          return;
        }
        final uri = adminPatientPhoneUri(patient);
        final opened =
            await (widget.openPhone?.call(uri) ??
                launchUrl(uri, mode: LaunchMode.externalApplication));
        if (!opened && _alive(op)) {
          throw const AppFailure('Could not open the phone dialer.');
        }
      } else if (action == 'progress') {
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
            repository: widget.repository.views,
            patient: patient,
          ),
        );
      } else if (profile.value('presc_active') != '1') {
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
                  if (adminPatientSearchScope(fresh) !=
                      adminPatientSearchScope(profile)) {
                    _needsRefresh = true;
                    throw const AppFailure(
                      'Patient access changed. Close this sheet and search again.',
                    );
                  }
                  return widget.repository.views.history(
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
        if (!mounted || id == null || !_alive(op)) return;
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
          _opening = _checking = _away = false;
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
    final m = DynamicRxMetrics(context);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: DocColors.primary),
    );
    return PopScope(
      canPop: !_busy && !_opening,
      child: NativePatientSearchShell(
        title: 'Patient Search',
        onBack: _busy || _opening ? null : () => Navigator.pop(context),
        child: Stack(
          children: [
            CustomScrollView(
              key: const Key('admin_patient_search_scroll'),
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: TextButton(
                            key: const Key('admin_patient_search_year'),
                            onPressed: _ready ? _pickYear : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Year: $_year',
                                  style: m.text(
                                    12,
                                    color: DocColors.greenSea,
                                    weight: FontWeight.w700,
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
                                borderRadius: BorderRadius.circular(10),
                                child: TextField(
                                  key: const Key('admin_patient_search_query'),
                                  controller: _search,
                                  focusNode: _focus,
                                  enabled:
                                      !_busy &&
                                      !_opening &&
                                      _current &&
                                      _foreground,
                                  textInputAction: TextInputAction.done,
                                  keyboardType: TextInputType.text,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  smartDashesType: SmartDashesType.disabled,
                                  smartQuotesType: SmartQuotesType.disabled,
                                  textCapitalization: TextCapitalization.none,
                                  style: m.text(
                                    10,
                                    color: patientSearchText,
                                    weight: FontWeight.w700,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    labelText: 'Write Patient Name or Code',
                                    labelStyle: m.text(
                                      10,
                                      color: const Color(0xffb2bec3),
                                      weight: FontWeight.w600,
                                    ),
                                    floatingLabelStyle:
                                        WidgetStateTextStyle.resolveWith(
                                          (states) => m.text(
                                            11,
                                            color:
                                                states.contains(
                                                      WidgetState.focused,
                                                    )
                                                    ? DocColors.primary
                                                    : const Color(0xff666666),
                                          ),
                                        ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: m.d(12),
                                      vertical: m.d(14),
                                    ),
                                    border: outline,
                                    enabledBorder: outline,
                                    focusedBorder: outline,
                                    disabledBorder: outline,
                                  ),
                                  onChanged:
                                      (text) => setState(
                                        () =>
                                            _helper =
                                                adminPatientSearchInvalidCharacter(
                                                      text,
                                                    )
                                                    ? 'Invalid Character'
                                                    : '',
                                      ),
                                  onSubmitted: (_) => _focus.unfocus(),
                                ),
                              ),
                            ),
                            SizedBox(width: m.d(8)),
                            SizedBox(
                              width: m.d(43),
                              height: m.d(43),
                              child: ElevatedButton(
                                key: const Key('admin_patient_search_submit'),
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
                        ),
                      ),
                      if (_helper.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            m.d(7),
                            2,
                            m.d(7),
                            m.d(7),
                          ),
                          child: Text(
                            _helper,
                            key: const Key('admin_patient_search_helper'),
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              color: Color(0xffff4444),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (_committedSearch != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: m.d(4)),
                            child: ElevatedButton(
                              key: const Key('admin_patient_search_clear'),
                              onPressed: _ready ? _clear : null,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(64, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                elevation: 1.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(m.d(15)),
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: 'PatuaOne',
                                  fontSize: 13,
                                ),
                              ),
                              child: const Text('CLEAR'),
                            ),
                          ),
                        ),
                      if (_committedSearch == null && _rows.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            m.d(4),
                            m.d(8),
                            m.d(4),
                            0,
                          ),
                          child: Text(
                            'Latest 100 Patients',
                            key: const Key(
                              'admin_patient_search_recent_message',
                            ),
                            style: m.text(
                              12,
                              color: DocColors.primary,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (!_busy && _error == null && _rows.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: m.d(4),
                            vertical: m.d(8),
                          ),
                          child: Text(
                            'No Patient Found',
                            key: const Key('admin_patient_search_empty'),
                            textAlign: TextAlign.center,
                            style: m.text(
                              12,
                              color: patientSearchText,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      SizedBox(height: m.d(8)),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(m.d(4), 0, m.d(4), m.d(8)),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((_, index) {
                      final patient = _rows[index];
                      return NativePatientSearchCard(
                        patient: patient,
                        dynamicMode: false,
                        onPrescription:
                            _ready
                                ? () =>
                                    unawaited(_open(patient, 'prescription'))
                                : null,
                        onAppointments:
                            _ready
                                ? () =>
                                    unawaited(_open(patient, 'appointments'))
                                : null,
                        onProgress:
                            _ready
                                ? () => unawaited(_open(patient, 'progress'))
                                : null,
                        onCall:
                            _profile != null &&
                                    adminPatientMayCall(_profile!, patient)
                                ? () => unawaited(_open(patient, 'call'))
                                : null,
                      );
                    }, childCount: _rows.length),
                  ),
                ),
              ],
            ),
            if (_busy || _checking)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0xeeffffff),
                  child: Center(
                    child: CircularProgressIndicator(
                      key: Key('admin_patient_search_progress'),
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
