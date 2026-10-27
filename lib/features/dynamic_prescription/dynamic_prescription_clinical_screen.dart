import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import 'dynamic_clinical_models.dart';
import 'dynamic_prescription_repository.dart';
import 'dynamic_prescription_seed.dart';
import 'dynamic_rx_models.dart';
import 'native_dynamic_builder_layout.dart';
import 'native_dynamic_clinical_tab.dart';
import 'native_dynamic_patient_details_sheet.dart';
import 'native_dynamic_rx_controls.dart';
import 'native_dynamic_rx_tab.dart';

/// Today's native scheduled builder. Clinical and Rx drafts live for this route.
class DynamicPrescriptionClinicalScreen extends StatefulWidget {
  const DynamicPrescriptionClinicalScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.seed,
  });
  final AuthController auth;
  final DynamicPrescriptionRepository repository;
  final DynamicPrescriptionSeed seed;
  @override
  State<DynamicPrescriptionClinicalScreen> createState() =>
      _ClinicalScreenState();
}

class _ClinicalScreenState extends State<DynamicPrescriptionClinicalScreen>
    with WidgetsBindingObserver {
  final _draft = DynamicClinicalDraft();
  final _rxDraft = DynamicRxDraft();
  final _pages = PageController();
  final _view = ValueNotifier<int>(0);
  final _navigator = GlobalKey<NavigatorState>();
  final _dialogs = NativeDashboardDialogOwner();
  AuthSession? _session;
  AccountProfile? _profile;
  DynamicClinicalCatalogue? _catalogue;
  DynamicRxCatalogue? _rxCatalogue;
  JsonMap _data = const {};
  BuildContext? _innerContext;
  String? _error, _baseline;
  bool _busy = true, _foreground = true, _initialized = false, _leaving = false;
  int _operation = 0;
  int _selectedTab = 0;
  bool get _current =>
      mounted &&
      _session != null &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool _alive(int operation) =>
      _current && _foreground && operation == _operation;
  bool get _ready =>
      _current &&
      _foreground &&
      !_busy &&
      _error == null &&
      _catalogue != null &&
      _rxCatalogue != null &&
      _profile != null;
  String get _snapshot => jsonEncode({
    'clinical': _draft.toBody(),
    'vitals': _draft.vitals?.values,
    // Dirty state includes all local Rx entries even if permission later changes.
    'rx': _rxDraft.toBody(medicineAllowed: true),
  });
  bool get _dirty => _baseline != null && _snapshot != _baseline;
  void _answer(bool value) {
    final inner = _innerContext;
    if (_current &&
        _foreground &&
        _dialogs.isOpen &&
        inner != null &&
        inner.mounted) {
      Navigator.of(inner).pop(value);
    }
  }

  void _refresh(void Function() change) {
    if (!mounted) return;
    change();
    _view.value++;
  }

  @override
  void initState() {
    super.initState();
    _session = widget.auth.session;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) {
        unawaited(_load());
      } else if (mounted) {
        _refresh(() {
          _busy = false;
          _error = 'Prescription details are unavailable.';
        });
      }
    });
  }

  void _closeSheets() {
    _dialogs.close();
    // All patient edit sheets are scoped to this nested navigator. Removing this
    // screen cannot leave a patient sheet above Login or a different account.
    _navigator.currentState?.popUntil((route) => route.isFirst);
  }

  void _authChanged() {
    if (_current) return;
    ++_operation;
    _closeSheets();
    _refresh(() {
      _profile = null;
      _catalogue = null;
      _rxCatalogue = null;
      _data = const {};
      _busy = true;
    });
    _draft.replaceFromData(const {});
    _rxDraft.replaceFromData(const {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _foreground = false;
      ++_operation;
      _closeSheets();
      _refresh(() {});
    } else if (!_foreground) {
      _foreground = true;
      if (_current) unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (!_current || !_foreground || _dialogs.isOpen) return;
    final operation = ++_operation;
    _refresh(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await widget.auth.profiles.open(
        _session!,
        recordLogin: false,
        isCurrent: () => _alive(operation),
      );
      widget.repository.guard(
        _session!,
        profile,
        widget.seed,
        () => _alive(operation),
      );
      if (!_initialized) {
        final loaded = await Future.wait<Object>([
          widget.repository.clinical.load(
            _session!,
            profile,
            isCurrent: () => _alive(operation),
          ),
          widget.repository.existing(
            _session!,
            profile,
            widget.seed,
            isCurrent: () => _alive(operation),
          ),
          widget.repository.rx.load(
            _session!,
            profile,
            isCurrent: () => _alive(operation),
          ),
        ]);
        if (!_alive(operation)) return;
        final catalogue = loaded[0] as DynamicClinicalCatalogue,
            data = loaded[1] as JsonMap,
            rxCatalogue = loaded[2] as DynamicRxCatalogue;
        final rxData = DynamicRxData.fromData(data);
        _draft.replaceFromData(data);
        _rxDraft.replace(rxData);
        _catalogue = catalogue;
        _rxCatalogue = rxCatalogue;
        _data = data;
        _baseline = _snapshot;
        _initialized = true;
      }
      if (!_alive(operation)) return;
      _refresh(() {
        _profile = profile;
        _busy = false;
      });
    } catch (failure) {
      if (!_alive(operation) || failure is ObsoleteRequest) return;
      if (failure is AccountAccessFailure) {
        widget.auth.blockAccess(failure);
        return;
      }
      await _failed(failure, operation);
    }
  }

  Future<void> _failed(Object failure, int operation) async {
    if (!_alive(operation)) return;
    final message =
        failure is AppFailure
            ? failure.message
            : 'Server Problem or Internet Not Connected';
    _refresh(() {
      _busy = false;
      _error = message;
    });
    final context = _innerContext;
    if (context == null || !context.mounted) return;
    final retry = await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: const Key('dy_builder_error'),
        title: Text(
          widget.seed.existing && !_initialized
              ? 'Prescription Load Failed'
              : 'Error!',
        ),
        content: Text('$message\nPlease try again.'),
        actions: [
          TextButton(
            key: const Key('dy_builder_error_exit'),
            onPressed: () => _answer(false),
            child: const Text('Exit'),
          ),
          TextButton(
            key: const Key('dy_builder_error_retry'),
            onPressed: () => _answer(true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    if (!_alive(operation)) return;
    if (retry == true) {
      await _load();
    } else if (retry == false && mounted) {
      await _back();
    }
  }

  Future<void> _patient(BuildContext context) async {
    if (!_ready) return;
    final operation = _operation, profile = _profile!;
    await showNativeDynamicRxSheet<void>(
      context,
      NativeDynamicPatientDetailsSheet(
        load:
            () => widget.repository.patientDetails(
              _session!,
              profile,
              widget.seed,
              isCurrent: () => _alive(operation),
            ),
      ),
    );
  }

  Future<List<DynamicRxOption>> _values(String id) async {
    if (!_ready) throw const ObsoleteRequest();
    final operation = _operation;
    return widget.repository.clinical.objectiveValues(
      _session!,
      _profile!,
      id,
      isCurrent: () => _alive(operation),
    );
  }

  void _selectTab(int index) {
    if (!_ready || index < 0 || index > 1 || !_pages.hasClients) return;
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(
      _pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _back() async {
    if (_leaving) return;
    final nested = _navigator.currentState;
    if (nested?.canPop() ?? false) {
      nested!.pop();
      return;
    }
    _leaving = true;
    try {
      if (_dirty && _current) {
        final context = _innerContext;
        if (context == null || !context.mounted) return;
        final discard = await _dialogs.show<bool>(
          context,
          AlertDialog(
            key: const Key('dy_unsaved'),
            title: const Text('Unsaved changes'),
            content: const Text(
              'You have unsaved prescription changes. Do you want to discard them and exit?',
            ),
            actions: [
              TextButton(
                key: const Key('dy_discard'),
                onPressed: () => _answer(true),
                child: const Text('DISCARD & EXIT'),
              ),
              TextButton(
                key: const Key('dy_keep_editing'),
                onPressed: () => _answer(false),
                child: const Text('KEEP EDITING'),
              ),
            ],
          ),
          dismissible: true,
        );
        if (!mounted || discard != true) return;
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      _leaving = false;
    }
  }

  Widget _layout(BuildContext context) {
    _innerContext = context;
    if (!_current) return const ColoredBox(color: Colors.white);
    Widget body;
    if (_initialized && _catalogue != null && _rxCatalogue != null) {
      // Keep both tabs mounted while rechecking access after resume. Replacing
      // the body with a loading widget would reset their scroll and expansion.
      body = Stack(
        children: [
          IgnorePointer(
            ignoring: !_ready,
            child: PageView(
              key: ValueKey(
                'dynamic_pages:${widget.seed.appointmentId}:${widget.seed.patientHistoryId}',
              ),
              controller: _pages,
              physics: _ready ? null : const NeverScrollableScrollPhysics(),
              allowImplicitScrolling: true,
              onPageChanged: (index) => _refresh(() => _selectedTab = index),
              children: [
                NativeDynamicClinicalTab(
                  key: ValueKey(
                    'clinical:${widget.seed.appointmentId}:${widget.seed.patientHistoryId}',
                  ),
                  draft: _draft,
                  catalogue: _catalogue!,
                  loadObjectiveValues: _values,
                ),
                NativeDynamicRxTab(
                  key: ValueKey(
                    'rx:${widget.seed.appointmentId}:${widget.seed.patientHistoryId}',
                  ),
                  draft: _rxDraft,
                  catalogue: _rxCatalogue!,
                  medicineAllowed: _profile?.value('med_active') == '1',
                ),
              ],
            ),
          ),
          if (!_ready)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white.withValues(alpha: .8),
                child: Center(
                  child:
                      _busy
                          ? const CircularProgressIndicator(
                            color: DynamicRxColors.primary,
                          )
                          : TextButton(
                            key: const Key('dy_builder_retry'),
                            onPressed:
                                _current && _foreground
                                    ? () => unawaited(_load())
                                    : null,
                            child: Text(
                              _error ?? 'Prescription details are unavailable.',
                            ),
                          ),
                ),
              ),
            ),
        ],
      );
    } else if (_busy) {
      body = const Center(
        child: CircularProgressIndicator(color: DynamicRxColors.primary),
      );
    } else if (_error != null || _catalogue == null) {
      body = Center(
        child: TextButton(
          key: const Key('dy_builder_retry'),
          onPressed: _current && _foreground ? () => unawaited(_load()) : null,
          child: Text(_error ?? 'Prescription details are unavailable.'),
        ),
      );
    } else {
      body = const SizedBox.shrink();
    }
    return NativeDynamicBuilderLayout(
      seed: widget.seed,
      data: _data,
      onBack: () => unawaited(_back()),
      onPatient: () => unawaited(_patient(context)),
      body: body,
      enabled: _ready,
      selectedTab: _selectedTab,
      onTabChanged: _selectTab,
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (popped, _) {
      if (!popped) unawaited(_back());
    },
    child: Navigator(
      key: _navigator,
      onGenerateRoute:
          (_) => MaterialPageRoute<void>(
            builder:
                (inner) => ListenableBuilder(
                  listenable: Listenable.merge([_view, _draft, _rxDraft]),
                  builder: (context, _) => _layout(context),
                ),
          ),
    ),
  );
  @override
  void dispose() {
    ++_operation;
    widget.auth.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    _dialogs.dispose();
    _view.dispose();
    _draft.dispose();
    _rxDraft.dispose();
    _pages.dispose();
    super.dispose();
  }
}
