import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/app_toast.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import 'dynamic_clinical_models.dart';
import 'dynamic_advice_models.dart';
import 'dynamic_prescription_repository.dart';
import 'dynamic_prescription_seed.dart';
import 'dynamic_rx_models.dart';
import 'native_dynamic_builder_layout.dart';
import 'native_dynamic_clinical_tab.dart';
import 'native_dynamic_patient_details_sheet.dart';
import 'native_dynamic_rx_controls.dart';
import 'native_dynamic_rx_tab.dart';
import 'native_dynamic_advice_tab.dart';
import 'dynamic_prescription_review_models.dart';
import 'dynamic_prescription_save_models.dart';
import 'native_dynamic_review_tab.dart';

/// Today's native scheduled builder: shared drafts, native review and save.
class DynamicPrescriptionClinicalScreen extends StatefulWidget {
  const DynamicPrescriptionClinicalScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.seed,
    this.durationRequired = false,
  });
  final AuthController auth;
  final DynamicPrescriptionRepository repository;
  final DynamicPrescriptionSeed seed;
  final bool durationRequired;
  @override
  State<DynamicPrescriptionClinicalScreen> createState() =>
      _ClinicalScreenState();
}

class _ClinicalScreenState extends State<DynamicPrescriptionClinicalScreen>
    with WidgetsBindingObserver {
  final _draft = DynamicClinicalDraft();
  final _rxDraft = DynamicRxDraft();
  final _adviceDraft = DynamicAdviceDraft();
  late final _review = DynamicPrescriptionReview(
    clinical: _draft,
    rx: _rxDraft,
    advice: _adviceDraft,
  );
  final _pages = PageController();
  final _view = ValueNotifier<int>(0);
  final _navigator = GlobalKey<NavigatorState>();
  final _dialogs = NativeDashboardDialogOwner();
  final _toast = AppToastOwner();
  AuthSession? _session;
  AccountProfile? _profile;
  DynamicClinicalCatalogue? _catalogue;
  DynamicRxCatalogue? _rxCatalogue;
  DynamicAdviceCatalogue? _adviceCatalogue;
  JsonMap _data = const {};
  BuildContext? _innerContext;
  String? _error, _baseline;
  bool _busy = true, _foreground = true, _initialized = false, _leaving = false;
  int _operation = 0;
  int _selectedTab = 0;
  int _saveOperation = 0;
  bool _saving = false, _uncertainCreate = false, _blockingFeedback = false;
  DynamicPrescriptionSaveReceipt? _pendingReceipt;
  String? _pendingSaveError;
  bool _writeCurrent(int operation) => _current && operation == _saveOperation;
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
      _adviceCatalogue != null &&
      _profile != null;
  String get _snapshot => jsonEncode({
    'clinical': _draft.toBody(),
    'vitals': _draft.vitals?.values,
    // Dirty state includes all local Rx entries even if permission later changes.
    'rx': _rxDraft.toBody(medicineAllowed: true),
    'advice': _adviceDraft.toBody(),
    'reference': _adviceDraft.reference,
    'prescription_notes': _adviceDraft.notes,
    'disease_template_id': dynamicRxText(_data['td_id']),
    'treatment_template_id': dynamicRxText(_data['tt_id']),
    'prescription_type': '1',
  });
  bool get _dirty {
    if (_baseline == null) return false;
    try {
      return _snapshot != _baseline;
    } on AppFailure {
      return true;
    }
  }

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
    ++_saveOperation;
    _closeSheets();
    _refresh(() {
      _profile = null;
      _catalogue = null;
      _rxCatalogue = null;
      _adviceCatalogue = null;
      _data = const {};
      _busy = true;
      _saving = false;
      _pendingReceipt = null;
      _pendingSaveError = null;
    });
    _draft.replaceFromData(const {});
    _rxDraft.replaceFromData(const {});
    _adviceDraft.replaceFromData(const {});
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
          widget.repository.advice.load(
            _session!,
            profile,
            isCurrent: () => _alive(operation),
          ),
        ]);
        if (!_alive(operation)) return;
        final catalogue = loaded[0] as DynamicClinicalCatalogue,
            data = loaded[1] as JsonMap,
            rxCatalogue = loaded[2] as DynamicRxCatalogue,
            adviceCatalogue = loaded[3] as DynamicAdviceCatalogue;
        final rxData = DynamicRxData.fromData(data);
        final adviceData = DynamicAdviceData.fromData(data);
        _draft.replaceFromData(data);
        _rxDraft.replace(rxData);
        _adviceDraft.replace(adviceData);
        _catalogue = catalogue;
        _rxCatalogue = rxCatalogue;
        _adviceCatalogue = adviceCatalogue;
        _data = data;
        _baseline = _snapshot;
        _initialized = true;
      }
      if (!_alive(operation)) return;
      _review.medicineAllowed = profile.value('med_active') == '1';
      _refresh(() {
        _profile = profile;
        _busy = false;
      });
      unawaited(_showSaveFeedback());
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
    if (!_ready || _saving || index < 0 || index > 3 || !_pages.hasClients) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(
      _pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _save() async {
    if (!_ready || _saving || !_review.canGenerate) return;
    final context = _innerContext;
    if (context == null || !context.mounted) return;
    if (_review.incompleteObjectives.isNotEmpty) {
      final updating = dynamicRxText(_data['rvm_id']).isNotEmpty;
      final go = await _dialogs.show<bool>(
        context,
        AlertDialog(
          key: const Key('dy_objective_required'),
          title: const Text('Objective Information Required'),
          content: Text(
            'Please select a value or enter notes for the following Objective Info before '
            '${updating ? 'updating' : 'generating'} the prescription:\n'
            '${_review.incompleteObjectives.map((name) => '• $name').join('\n')}',
          ),
          actions: [
            TextButton(
              key: const Key('dy_objective_cancel'),
              onPressed: () => _answer(false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              key: const Key('dy_objective_go'),
              onPressed: () => _answer(true),
              child: const Text('GO TO CLINICAL'),
            ),
          ],
        ),
        dismissible: true,
      );
      if (_current && _foreground && go == true) {
        _review.reset();
        _selectTab(0);
      }
      return;
    }
    final operation = ++_saveOperation;
    _refresh(() => _saving = true);
    try {
      // Refresh account access before the one native write. Backgrounding before
      // this check completes never starts a POST; a dispatched POST is not resent.
      final profile = await widget.auth.profiles.open(
        _session!,
        recordLogin: false,
        isCurrent: () => _writeCurrent(operation) && _foreground,
      );
      widget.repository.guard(
        _session!,
        profile,
        widget.seed,
        () => _writeCurrent(operation) && _foreground,
      );
      _profile = profile;
      _review.medicineAllowed = profile.value('med_active') == '1';
      if (!_review.canGenerate) {
        throw const AppFailure('Please review and confirm the prescription');
      }
      if (_uncertainCreate && dynamicRxText(_data['rvm_id']).isEmpty) {
        // A lost create response must never become a second insert. A found
        // record binds this builder to UPDATE; the local draft stays intact.
        try {
          final found = await widget.repository.lookup(
            _session!,
            profile,
            widget.seed,
            isCurrent: () => _writeCurrent(operation),
          );
          if (!_writeCurrent(operation)) return;
          _refresh(() {
            _data = {
              ..._data,
              'rvm_id': found['rvm_id'],
              'rvm_code': found['rvm_code'],
            };
            _uncertainCreate = false;
          });
          _review.reset();
          _pendingSaveError =
              'A prescription was found for this appointment. Your draft is kept. Review it again before pressing UPDATE.';
        } catch (failure) {
          if (failure is ObsoleteRequest || failure is AccountAccessFailure) {
            rethrow;
          }
          _pendingSaveError =
              'The previous save could not be confirmed. Your draft is kept. Reopen the appointment to check its saved prescription before trying again.';
          _review.reset();
        }
        return;
      }
      final request = DynamicPrescriptionSaveRequest.capture(
        seed: widget.seed,
        profile: profile,
        review: _review,
        data: _data,
      );
      final savedSnapshot = _snapshot;
      final receipt = await widget.repository.save(
        _session!,
        profile,
        widget.seed,
        request,
        isCurrent: () => _writeCurrent(operation),
      );
      if (!_writeCurrent(operation)) return;
      _refresh(() {
        _data = {
          ..._data,
          'rvm_id': receipt.rvmId,
          if (receipt.code.isNotEmpty) 'rvm_code': receipt.code,
        };
        _baseline = savedSnapshot;
        _uncertainCreate = false;
        _pendingReceipt = receipt;
      });
      _review.reset();
    } catch (failure) {
      if (!_writeCurrent(operation) || failure is ObsoleteRequest) return;
      if (failure is AccountAccessFailure) {
        widget.auth.blockAccess(failure);
        return;
      }
      if (failure is DynamicPrescriptionSaveFailure) {
        if (dynamicRxText(_data['rvm_id']).isEmpty) _uncertainCreate = true;
        _review.reset();
      }
      _pendingSaveError =
          failure is AppFailure
              ? failure.message
              : 'Prescription failed to create. Please check your network and try again.';
    } finally {
      if (_writeCurrent(operation)) {
        _refresh(() => _saving = false);
        unawaited(_showSaveFeedback());
      }
    }
  }

  Future<void> _showSaveFeedback() async {
    final context = _innerContext;
    if (!_ready ||
        _saving ||
        _dialogs.isOpen ||
        context == null ||
        !context.mounted) {
      return;
    }
    final receipt = _pendingReceipt, error = _pendingSaveError;
    if (receipt == null && error == null) return;
    _pendingReceipt = null;
    _pendingSaveError = null;
    _blockingFeedback = receipt != null;
    final message =
        receipt == null
            ? error!
            : receipt.message +
                (!receipt.updating && receipt.code.isNotEmpty
                    ? '\nPrescription Code: ${receipt.code}'
                    : '');
    try {
      final acknowledged = await _dialogs.show<bool>(
        context,
        AlertDialog(
          key: Key(receipt == null ? 'dy_save_error' : 'dy_save_success'),
          title: Text(receipt == null ? 'Error!' : 'Success'),
          content: Text(message),
          actions: [
            TextButton(
              key: const Key('dy_save_ok'),
              onPressed: () => _answer(true),
              child: const Text('OK'),
            ),
          ],
        ),
        dismissible: receipt == null,
      );
      if (_current && !_foreground && acknowledged != true) {
        _pendingReceipt = receipt;
        _pendingSaveError = error;
      }
    } finally {
      _blockingFeedback = false;
    }
  }

  Future<void> _back() async {
    if (_saving) {
      _toast.show(context, 'Please wait while the prescription is being saved');
      return;
    }
    if (_blockingFeedback && _dialogs.isOpen) return;
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
    if (_initialized &&
        _catalogue != null &&
        _rxCatalogue != null &&
        _adviceCatalogue != null) {
      // Keep all tabs mounted while rechecking access after resume. Replacing
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
                  durationRequired: widget.durationRequired,
                ),
                NativeDynamicAdviceTab(
                  key: ValueKey(
                    'advice:${widget.seed.appointmentId}:${widget.seed.patientHistoryId}',
                  ),
                  draft: _adviceDraft,
                  catalogue: _adviceCatalogue!,
                ),
                NativeDynamicReviewTab(
                  key: ValueKey(
                    'review:${widget.seed.appointmentId}:${widget.seed.patientHistoryId}',
                  ),
                  review: _review,
                  onEdit: _selectTab,
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
    final frame = NativeDynamicBuilderLayout(
      seed: widget.seed,
      data: _data,
      onBack: () => unawaited(_back()),
      onPatient: () => unawaited(_patient(context)),
      body: body,
      enabled: _ready && !_saving,
      selectedTab: _selectedTab,
      onTabChanged: _selectTab,
      hasRx: _review.hasRx,
      reviewConfirmed: _review.confirmed,
      onConfirm: _review.confirm,
      onSave: () => unawaited(_save()),
    );
    return Stack(
      children: [
        IgnorePointer(
          ignoring: _saving,
          child: Opacity(opacity: _saving ? 0 : 1, child: frame),
        ),
        if (_saving)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.white,
              child: Center(
                child: CircularProgressIndicator(
                  key: Key('dy_save_progress'),
                  color: DynamicRxColors.primary,
                ),
              ),
            ),
          ),
      ],
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
                  listenable: Listenable.merge([
                    _view,
                    _draft,
                    _rxDraft,
                    _adviceDraft,
                    _review,
                  ]),
                  builder: (context, _) => _layout(context),
                ),
          ),
    ),
  );
  @override
  void dispose() {
    ++_operation;
    ++_saveOperation;
    widget.auth.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    _dialogs.dispose();
    _view.dispose();
    _toast.dispose();
    _review.dispose();
    _draft.dispose();
    _rxDraft.dispose();
    _adviceDraft.dispose();
    _pages.dispose();
    super.dispose();
  }
}
