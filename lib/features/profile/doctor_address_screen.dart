import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/failure.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import 'doctor_address_repository.dart';
import 'doctor_profile_repository.dart';
import 'native_doctor_address_layout.dart';

class DoctorAddressScreen extends StatefulWidget {
  const DoctorAddressScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.details,
  });
  final AuthController auth;
  final DoctorAddressRepository repository;
  final DoctorProfileDetails? details;
  @override
  State<DoctorAddressScreen> createState() => _DoctorAddressScreenState();
}

class _DoctorAddressScreenState extends State<DoctorAddressScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  final _street = TextEditingController();
  final _postOffice = TextEditingController();
  final _thana = TextEditingController();
  final _district = TextEditingController();
  final _streetFocus = FocusNode(),
      _postOfficeFocus = FocusNode(),
      _thanaFocus = FocusNode();
  final _dialogs = NativeDashboardDialogOwner();
  List<DoctorThana> _thanas = const [];
  DoctorThana? _selected;
  String? _streetHelper, _postOfficeHelper, _thanaHelper;
  bool _invalidSession = false,
      _foreground = true,
      _busy = true,
      _saving = false;
  bool _backgrounded = false;
  int _operation = 0;
  Completer<void>? _resume;

  bool get _current =>
      mounted &&
      !_invalidSession &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool current(int operation) => _current && operation == _operation;
  bool get _canAct =>
      _current && _foreground && !_busy && !_saving && !_dialogs.isOpen;

  @override
  void initState() {
    super.initState();
    final session = widget.auth.session;
    if (session == null || widget.auth.profile == null) {
      _invalidSession = true;
      _busy = false;
      return;
    }
    _session = session;
    final data = widget.details;
    _street.text = data?.value('doc_village') ?? '';
    _postOffice.text = data?.value('doc_poffice') ?? '';
    _thana.text = data?.value('dd_thana_name') ?? '';
    _district.text = data?.value('dist_name') ?? '';
    final id = data?.value('doc_dd_id') ?? '';
    if (id.isNotEmpty && _thana.text.isNotEmpty) {
      _selected = DoctorThana(
        id: id,
        districtId: data?.value('dist_id') ?? '',
        name: _thana.text,
        district: _district.text,
      );
    }
    _streetFocus.addListener(_streetBlur);
    _postOfficeFocus.addListener(_postOfficeBlur);
    _thanaFocus.addListener(_thanaBlur);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) {
        unawaited(_load());
      }
    });
  }

  void _streetBlur() {
    if (!_streetFocus.hasFocus && _current && !_busy) {
      setState(
        () =>
            _streetHelper =
                _street.text.trim().isEmpty
                    ? 'Please Provide Street Address/Village'
                    : null,
      );
    }
  }

  void _postOfficeBlur() {
    if (!_postOfficeFocus.hasFocus && _current && !_busy) {
      setState(
        () =>
            _postOfficeHelper =
                _postOffice.text.trim().isEmpty
                    ? 'Please Provide Post Office'
                    : null,
      );
    }
  }

  void _thanaBlur() {
    if (!_thanaFocus.hasFocus && _current && !_busy) {
      _resolveThana();
    }
  }

  void _resolveThana() {
    var selected = _selected;
    if (selected == null || selected.name != _thana.text) {
      selected = DoctorThana.named(_thanas, _thana.text);
    }
    setState(() {
      _selected = selected;
      _district.text = selected?.district ?? '';
      _thanaHelper =
          selected == null || selected.id.isEmpty
              ? (_thana.text.isEmpty
                  ? 'Please Select Thana/Upazila'
                  : 'Invalid Thana/Upazila')
              : null;
    });
  }

  void _selectThana(DoctorThana item) {
    // The native adapter displays names and resolves the last exact name match.
    final selected = DoctorThana.named(_thanas, item.name) ?? item;
    setState(() {
      _selected = selected;
      _thana.text = selected.name;
      _thana.selection = TextSelection.collapsed(offset: _thana.text.length);
      _district.text = selected.district;
      _thanaHelper = selected.id.isEmpty ? 'Please Select Thana/Upazila' : null;
    });
  }

  void _wake() {
    final pending = _resume;
    _resume = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }

  Future<bool> _ready(int operation) async {
    while (current(operation) && !_foreground) {
      await (_resume ??= Completer<void>()).future;
    }
    return current(operation);
  }

  void _authChanged() {
    if (!_current) {
      ++_operation;
      _wake();
      _dialogs.close();
      if (mounted) {
        setState(() => _busy = true);
      }
    }
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_saving) {
      _foreground = foreground;
      if (foreground) {
        _wake();
      } else {
        _backgrounded = true;
      }
      return;
    }
    if (!foreground) {
      _foreground = false;
      ++_operation;
      _dialogs.close();
    } else if (!_foreground) {
      _foreground = true;
      if (_current) {
        unawaited(_load());
      }
    }
  }

  Future<void> _load() async {
    if (!_current || !_foreground) {
      return;
    }
    final operation = ++_operation;
    setState(() => _busy = true);
    try {
      final profile = await widget.auth.profiles.open(
        _session,
        recordLogin: false,
        isCurrent: () => current(operation) && _foreground,
      );
      final data = await widget.repository.loadThanas(
        _session,
        profile,
        isCurrent: () => current(operation) && _foreground,
      );
      if (!current(operation) || !_foreground) {
        return;
      }
      setState(() {
        _thanas = data;
        _busy = false;
        _thanaHelper = data.isEmpty ? 'No Thana/Upazila Found' : null;
      });
    } catch (failure) {
      if (current(operation) && _foreground && !_deny(failure)) {
        setState(() => _busy = false);
        final retry = await _error(failure, operation, writing: false);
        if (!current(operation) || !mounted) {
          return;
        }
        if (retry == true) {
          await _load();
        } else if (retry == false) {
          await _back();
        }
      }
    }
  }

  Future<bool?> _error(
    Object failure,
    int operation, {
    required bool writing,
  }) async {
    if (!await _ready(operation) || !mounted) {
      return null;
    }
    return await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: Key(writing ? 'address_save_error' : 'address_load_error'),
        title: Text(
          'Error!',
          style: dashboardDialogText(20, weight: FontWeight.w500),
        ),
        content: SingleChildScrollView(
          child: Text(
            dashboardErrorMessage(failure),
            style: dashboardDialogText(16),
          ),
        ),
        actions: [
          TextButton(
            key: Key(writing ? 'address_save_cancel' : 'address_load_exit'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              writing ? 'Cancel' : 'Exit',
              style: dashboardDialogText(14, color: DocColors.primary),
            ),
          ),
          TextButton(
            key: Key(writing ? 'address_save_retry' : 'address_load_retry'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Retry',
              style: dashboardDialogText(14, color: DocColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _notice(String message) {
    if (_current && _foreground) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom -
                    120)
                .clamp(0.0, 88.0)
                .toDouble(),
          ),
        ),
      );
    }
  }

  Future<void> _back() async {
    if (_busy || _saving) {
      _notice('Please wait while loading');
      return;
    }
    await Navigator.of(context).maybePop();
  }

  Future<void> _update() async {
    if (!_canAct) {
      return;
    }
    FocusScope.of(context).unfocus();
    _resolveThana();
    final draft = DoctorAddressDraft(
      street: _street.text,
      postOffice: _postOffice.text,
      thanaId: _selected?.id ?? '',
    );
    final invalid = draft.validationMessage;
    if (invalid != null) {
      setState(() {
        if (_street.text.trim().isEmpty) {
          _streetHelper = invalid;
        } else if (_postOffice.text.trim().isEmpty) {
          _postOfficeHelper = invalid;
        } else if (draft.thanaId.isEmpty) {
          _thanaHelper = invalid;
        }
      });
      _notice(invalid);
      return;
    }
    final operation = ++_operation;
    bool alive() => current(operation);
    setState(() {
      _saving = true;
      _backgrounded = false;
    });
    var saved = false, verified = false;
    try {
      if (await _dialogs.show<bool>(
                context,
                const NativeDashboardConfirmDialog(
                  title: 'Update Address!',
                  message: 'Do you want to update your address?',
                ),
                dismissible: true,
              ) !=
              true ||
          !await _ready(operation)) {
        return;
      }
      while (await _ready(operation)) {
        setState(() => _busy = true);
        try {
          final profile = await widget.auth.profiles.open(
            _session,
            recordLogin: false,
            isCurrent: () => alive() && _foreground,
          );
          if (!saved) {
            _backgrounded = false;
            await widget.repository.update(
              _session,
              profile,
              draft,
              isCurrent: alive,
              isForeground: () => _foreground,
            );
            saved = true;
          }
          if (!await _ready(operation)) {
            return;
          }
          if (_backgrounded) {
            await widget.auth.profiles.open(
              _session,
              recordLogin: false,
              isCurrent: () => alive() && _foreground,
            );
          }
          if (!alive() || !mounted) {
            return;
          }
          verified = true;
          setState(() => _busy = false);
          final acknowledged = await _dialogs.show<bool>(
            context,
            const NativeDashboardMessageDialog(
              key: Key('address_success'),
              title: 'Success!',
              message: 'Address Updated Successfully.',
              button: 'Ok',
            ),
          );
          if (acknowledged == true && await _ready(operation) && mounted) {
            setState(() => _saving = false);
            Navigator.of(context).pop();
          }
          return;
        } catch (failure) {
          if (!alive() || _deny(failure)) {
            return;
          }
          if (!await _ready(operation)) {
            return;
          }
          setState(() => _busy = false);
          if (await _error(
                failure is ObsoleteRequest
                    ? const AppFailure(
                      'The app was paused. Please retry when ready.',
                    )
                    : failure,
                operation,
                writing: true,
              ) !=
              true) {
            return;
          }
        }
      }
    } finally {
      if (alive()) {
        setState(() {
          _busy = false;
          _saving = false;
        });
        if (_backgrounded && !verified && await _ready(operation)) {
          await _load();
        }
      }
    }
  }

  @override
  void dispose() {
    ++_operation;
    _wake();
    _dialogs.dispose();
    widget.auth.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    _streetFocus.removeListener(_streetBlur);
    _postOfficeFocus.removeListener(_postOfficeBlur);
    _thanaFocus.removeListener(_thanaBlur);
    for (final focus in [_streetFocus, _postOfficeFocus, _thanaFocus]) {
      focus.dispose();
    }
    for (final controller in [_street, _postOffice, _thana, _district]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _invalidSession
          ? Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could Not Get Doctor Data. Please return to Login.',
                    ),
                    TextButton(
                      onPressed: () => unawaited(_back()),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            ),
          )
          : PopScope(
            canPop: !_busy && !_saving,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && (_busy || _saving)) {
                _notice('Please wait while loading');
              }
            },
            child: NativeDoctorAddressLayout(
              loading: _busy,
              street: _street,
              postOffice: _postOffice,
              thana: _thana,
              district: _district,
              streetFocus: _streetFocus,
              postOfficeFocus: _postOfficeFocus,
              thanaFocus: _thanaFocus,
              thanas: _thanas,
              streetHelper: _streetHelper,
              postOfficeHelper: _postOfficeHelper,
              thanaHelper: _thanaHelper,
              onStreetChanged:
                  (value) => setState(
                    () =>
                        _streetHelper =
                            value.trim().isEmpty
                                ? 'Please Provide Street Address/Village'
                                : null,
                  ),
              onPostOfficeChanged:
                  (value) => setState(
                    () =>
                        _postOfficeHelper =
                            value.trim().isEmpty
                                ? 'Please Provide Post Office'
                                : null,
                  ),
              onThanaChanged:
                  (value) => setState(() {
                    _selected = null;
                    _district.clear();
                    _thanaHelper =
                        value.isEmpty ? 'Please Select Thana/Upazila' : null;
                  }),
              onThanaSelected: _selectThana,
              onClose: () => unawaited(_back()),
              onUpdate: () => unawaited(_update()),
            ),
          );
}
