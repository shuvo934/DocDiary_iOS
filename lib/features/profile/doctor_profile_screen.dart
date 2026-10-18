import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/failure.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../dashboard/dashboard_services.dart';
import '../dashboard/native_camera_screen.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import '../dashboard/native_photo_dialogs.dart';
import 'doctor_address_repository.dart';
import 'doctor_address_screen.dart';
import 'doctor_profile_repository.dart';
import 'native_doctor_profile_layout.dart';

enum DoctorProfileDestination { address, password }

typedef DoctorProfileDestinationBuilder =
    Widget? Function(
      BuildContext context,
      DoctorProfileDestination destination,
      DoctorProfileDetails? details,
    );

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.media = const IosDashboardPhotoMedia(),
    this.openVideo,
    this.destinationBuilder,
  });
  final AuthController auth;
  final DoctorProfileRepository repository;
  final DashboardPhotoMedia media;
  final Future<bool> Function(Uri)? openVideo;
  final DoctorProfileDestinationBuilder? destinationBuilder;
  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  late AccountProfile _profile;
  DoctorProfileDetails? _details;
  final _dialogs = NativeDashboardDialogOwner();
  bool _loading = true, _photoBusy = false, _foreground = true;
  bool _invalidSession = false;
  bool _photoBackgrounded = false, _childAway = false;
  int _operation = 0;
  Completer<void>? _resume;
  bool get _current =>
      mounted &&
      !_invalidSession &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool current(int operation) => _current && operation == _operation;
  bool get _canAct =>
      _current && _foreground && !_loading && !_photoBusy && !_dialogs.isOpen;

  @override
  void initState() {
    super.initState();
    final session = widget.auth.session;
    final profile = widget.auth.profile;
    if (session == null || profile == null) {
      _invalidSession = true;
      _loading = false;
      return;
    }
    _session = session;
    _profile = profile;
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

  void _authChanged() {
    if (!_current) {
      ++_operation;
      _wake();
      _dialogs.close();
      if (mounted) {
        setState(() {
          _details = null;
          _loading = true;
        });
      }
    }
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_photoBusy || _childAway) {
      _foreground = foreground;
      if (foreground) {
        _wake();
      } else {
        _photoBackgrounded = true;
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
    if (!_current || !_foreground) {
      return;
    }
    final operation = ++_operation;
    setState(() => _loading = true);
    try {
      final fresh = await widget.auth.profiles.open(
        _session,
        recordLogin: false,
        isCurrent: () => current(operation) && _foreground,
      );
      final data = await widget.repository.load(
        _session,
        fresh,
        isCurrent: () => current(operation) && _foreground,
      );
      if (!current(operation) || !_foreground) {
        return;
      }
      setState(() {
        _profile = fresh;
        _details = data;
        _loading = false;
      });
    } catch (failure) {
      if (current(operation) && _foreground && !_deny(failure)) {
        setState(() => _loading = false);
        await _loadError(failure, operation);
      }
    }
  }

  Future<void> _loadError(Object failure, int operation) async {
    if (!await _ready(operation) || !mounted) {
      return;
    }
    final retry = await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: const Key('profile_error'),
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
            key: const Key('profile_error_exit'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Exit',
              style: dashboardDialogText(14, color: DocColors.primary),
            ),
          ),
          TextButton(
            key: const Key('profile_error_retry'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Retry',
              style: dashboardDialogText(14, color: DocColors.primary),
            ),
          ),
        ],
      ),
    );
    if (!current(operation) || !mounted) {
      return;
    }
    if (retry == true) {
      await _load();
    } else if (retry == false) {
      await Navigator.of(context).maybePop();
    }
  }

  void _notice(String message) {
    if (_current && _foreground) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _back() async {
    if (_loading || _photoBusy) {
      _notice('Please wait while loading');
      return;
    }
    await Navigator.of(context).maybePop();
  }

  Future<void> _child(DoctorProfileDestination destination) async {
    if (!_canAct) {
      return;
    }
    final page =
        widget.destinationBuilder?.call(context, destination, _details) ??
        (destination == DoctorProfileDestination.address
            ? DoctorAddressScreen(
              auth: widget.auth,
              repository: DoctorAddressRepository(
                widget.repository.transport,
                now: widget.repository.now,
              ),
              details: _details,
            )
            : null);
    if (page == null) {
      await _dialogs.show<void>(
        context,
        AlertDialog(
          title: Text(
            destination == DoctorProfileDestination.address
                ? 'Update Address'
                : 'Change Password',
          ),
          content: const Text(
            'This screen is not available in this development build.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    _childAway = true;
    try {
      await _dialogs.push<void>(context, page);
    } finally {
      _childAway = false;
      if (_current && await _ready(_operation)) {
        await _load();
      }
    }
  }

  Future<void> _video() async {
    if (!_canAct || _profile.value('doc_video_link_enable_flag') != '1') {
      return;
    }
    final value = _profile.value('doc_video_link').trim();
    if (value.isEmpty) {
      _notice('Video call is not available yet');
      return;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const ['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      _notice('Video call link is invalid. Please contact your administrator.');
      return;
    }
    try {
      final open =
          widget.openVideo ??
          ((Uri url) async =>
              await launchUrl(url, mode: LaunchMode.externalApplication));
      if (!await open(uri).timeout(const Duration(seconds: 10))) {
        _notice('Could not open the video call link.');
      }
    } catch (_) {
      _notice('Could not open the video call link.');
    }
  }

  Future<bool> _photoRetry(Object failure, int operation) async {
    if (!await _ready(operation) || !mounted) {
      return false;
    }
    setState(() => _loading = false);
    return await _dialogs.show<bool>(
              context,
              NativePhotoRetryDialog(failure: failure),
            ) ==
            true &&
        current(operation);
  }

  Future<void> _photo() async {
    if (!_canAct) {
      return;
    }
    final operation = ++_operation;
    bool alive() => current(operation);
    setState(() {
      _photoBusy = true;
      _photoBackgrounded = false;
    });
    var verified = false;
    try {
      final source = await _dialogs.show<DashboardPhotoSource>(
        context,
        const NativePhotoChoiceDialog(),
      );
      if (source == null || !await _ready(operation)) {
        return;
      }
      Uint8List? selected;
      do {
        try {
          selected = await widget.media.select(
            source,
            ready: () async => await _ready(operation),
            capture: () async {
              if (!await _ready(operation) || !mounted) {
                return null;
              }
              return await _dialogs.push<String>(
                context,
                const NativeCameraScreen(),
              );
            },
          );
          break;
        } catch (failure) {
          if (!await _photoRetry(failure, operation)) {
            return;
          }
        }
      } while (alive());
      if (selected == null || !await _ready(operation)) {
        return;
      }
      final jpeg = Uint8List.fromList(selected);
      var uploaded = false;
      while (await _ready(operation)) {
        setState(() => _loading = true);
        try {
          var fresh = await widget.auth.profiles.open(
            _session,
            recordLogin: false,
            isCurrent: () => alive() && _foreground,
          );
          if (!alive()) {
            return;
          }
          if (!uploaded) {
            _photoBackgrounded = false;
            await widget.repository.upload(
              _session,
              fresh,
              jpeg,
              isCurrent: alive,
              isForeground: () => _foreground,
            );
            uploaded = true;
          }
          if (!await _ready(operation)) {
            return;
          }
          if (_photoBackgrounded) {
            fresh = await widget.auth.profiles.open(
              _session,
              recordLogin: false,
              isCurrent: () => alive() && _foreground,
            );
          }
          if (!alive()) {
            return;
          }
          ProfileRepository.checkAccess(fresh, widget.repository.now());
          verified = true;
          setState(() {
            _profile = fresh;
            _details = (_details ?? DoctorProfileDetails({})).withPicture(jpeg);
            _loading = false;
          });
          _notice('Picture Uploaded');
          return;
        } catch (failure) {
          if (!alive() || _deny(failure)) {
            return;
          }
          if (!await _photoRetry(
            failure is ObsoleteRequest
                ? const AppFailure(
                  'The app was paused. Please retry when ready.',
                )
                : failure,
            operation,
          )) {
            return;
          }
        }
      }
    } finally {
      if (alive() &&
          _photoBackgrounded &&
          !verified &&
          await _ready(operation)) {
        try {
          final fresh = await widget.auth.profiles.open(
            _session,
            recordLogin: false,
            isCurrent: () => alive() && _foreground,
          );
          if (alive()) {
            setState(() => _profile = fresh);
          }
        } catch (failure) {
          if (alive() && !_deny(failure)) {
            setState(() {
              _loading = false;
              _photoBusy = false;
            });
            await _loadError(failure, operation);
          }
        }
      }
      if (mounted && operation == _operation) {
        setState(() {
          _photoBusy = false;
          _loading = false;
        });
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
            canPop: !_loading && !_photoBusy,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && (_loading || _photoBusy)) {
                _notice('Please wait while loading');
              }
            },
            child: NativeDoctorProfileLayout(
              profile: _profile,
              details: _details,
              loading: _loading,
              onBack: () => unawaited(_back()),
              onPhoto: () => unawaited(_photo()),
              onAddress:
                  () => unawaited(_child(DoctorProfileDestination.address)),
              onPassword:
                  () => unawaited(_child(DoctorProfileDestination.password)),
              onVideo: () => unawaited(_video()),
            ),
          );
}
