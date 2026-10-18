import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'auth_controller.dart';
import 'auth_models.dart';
import 'native_login_layout.dart';

const _centerMessage =
    'We have found Multiple Center for your login credentials. '
    'Please Select One to proceed.';
const _userMessage =
    'We have found Multiple USER ID for your login credentials. '
    'Please Select One to proceed.';

TextStyle _selectionText(
  String family,
  double size, {
  Color color = Colors.black87,
  FontWeight weight = FontWeight.normal,
}) => TextStyle(
  inherit: false,
  textBaseline: TextBaseline.alphabetic,
  fontFamily: family,
  fontSize: size,
  fontWeight: weight,
  color: color,
  // The bundled Open Sans file contains the native regular and bold faces.
  fontVariations:
      family == 'OpenSans' ? const [ui.FontVariation('wght', 700)] : null,
);

double _selectionSdp(BuildContext context) {
  final width = MediaQuery.sizeOf(context).shortestSide;
  return width < 300 ? 1 : (width / 30).floor() * 30 / 300;
}

/// Native SelectCenterDialogue / SelectUserIdDialogue and their row XML.
/// The controller still owns discovery, account selection and authentication.
class SelectionScreen extends StatefulWidget {
  const SelectionScreen({super.key, required this.controller});
  final AuthController controller;

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  String? _shownError;

  @override
  void initState() {
    super.initState();
    _scheduleError();
  }

  @override
  void didUpdateWidget(covariant SelectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleError();
  }

  void _scheduleError() {
    final message = widget.controller.error;
    if (message == null) {
      _shownError = null;
      return;
    }
    if (message == _shownError) {
      return;
    }
    _shownError = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.error == message) {
        unawaited(
          showDialog<void>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Warning!'),
                  content: Text(message),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final choosingAccount = controller.stage == AuthStage.chooseAccount;
    final center = controller.selectedCenter;
    final active = controller.session;
    final sdp = _selectionSdp(context);
    final title =
        choosingAccount && center != null ? center.name : 'SELECT CENTER';

    return PopScope(
      canPop: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ExcludeSemantics(
            child: TickerMode(
              enabled: false,
              child: NativeLoginProgressScreen(),
            ),
          ),
          const ModalBarrier(
            color: Color(0x99000000),
            dismissible: false,
            semanticsLabel: 'Account selection',
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = MediaQuery.sizeOf(context);
                // AppCompat's window minimum width is 95% in portrait, 65% in
                // landscape; AppCompat 1.7.1's API 21+ background adds 16dp insets.
                final fraction = size.width <= size.height ? .95 : .65;
                final width = math.max(
                  0.0,
                  math.min(
                    size.width * fraction - 32,
                    constraints.maxWidth - 32,
                  ),
                );
                final height = math.max(0.0, constraints.maxHeight - 32);
                return Center(
                  child: SizedBox(
                    width: width,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: height),
                      child: Semantics(
                        scopesRoute: true,
                        explicitChildNodes: true,
                        namesRoute: true,
                        label: title,
                        child: Material(
                          type: MaterialType.card,
                          color: Colors.white,
                          elevation: 24,
                          borderRadius: BorderRadius.circular(2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: height * .65,
                                ),
                                child: SingleChildScrollView(
                                  primary: false,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _SelectionHeader(
                                        title: title,
                                        onClose: controller.cancelSelection,
                                      ),
                                      if (active == null)
                                        Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Text(
                                            choosingAccount
                                                ? _userMessage
                                                : _centerMessage,
                                            textAlign: TextAlign.center,
                                            style: _selectionText(
                                              'Poppins',
                                              14,
                                              weight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Flexible(
                                child: ListView.builder(
                                  key: ValueKey(
                                    choosingAccount
                                        ? 'native_accounts_${center?.baseUri}'
                                        : 'native_centers',
                                  ),
                                  primary: false,
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.all(10),
                                  itemCount:
                                      choosingAccount
                                          ? center?.accounts.length ?? 0
                                          : controller.centers.length,
                                  itemBuilder: (context, index) {
                                    if (choosingAccount && center != null) {
                                      final account = center.accounts[index];
                                      final selected =
                                          active != null &&
                                          active.center.baseUri ==
                                              center.baseUri &&
                                          active.account.key == account.key;
                                      return _NativeSelectionCard(
                                        key: Key('account_$index'),
                                        selected: selected,
                                        sdp: sdp,
                                        onTap: () {
                                          if (controller.stage ==
                                                  AuthStage.chooseAccount &&
                                              !controller.busy) {
                                            unawaited(
                                              controller.selectAccount(account),
                                            );
                                          }
                                        },
                                        child: _AccountDetails(
                                          account: account,
                                          sdp: sdp,
                                        ),
                                      );
                                    }
                                    final item = controller.centers[index];
                                    return _NativeSelectionCard(
                                      key: Key('center_$index'),
                                      selected:
                                          active?.center.baseUri ==
                                          item.baseUri,
                                      sdp: sdp,
                                      onTap: () {
                                        if (controller.stage ==
                                                AuthStage.chooseCenter &&
                                            !controller.busy) {
                                          unawaited(
                                            controller.selectCenter(item),
                                          );
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(15),
                                        child: Text(
                                          item.name,
                                          textScaler: TextScaler.noScaling,
                                          style: _selectionText(
                                            'OpenSans',
                                            13 * sdp,
                                            color: DocColors.greenSea,
                                            weight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({required this.title, required this.onClose});
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    color: DocColors.primary,
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Image.asset(
          'assets/images/hospital_icon.png',
          width: 24,
          height: 24,
          color: Colors.white,
          colorBlendMode: BlendMode.srcIn,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              title,
              style: _selectionText(
                'Poppins',
                18,
                color: Colors.white,
                weight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Cancel selection',
          child: Semantics(
            button: true,
            label: 'Close selection',
            child: InkResponse(
              key: const Key('close_selection'),
              onTap: onClose,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _NativeSelectionCard extends StatelessWidget {
  const _NativeSelectionCard({
    super.key,
    required this.selected,
    required this.sdp,
    required this.onTap,
    required this.child,
  });
  final bool selected;
  final double sdp;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.white,
        elevation: 4,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? DocColors.clouds : Colors.white,
            border: Border.all(color: DocColors.muted, width: 2),
            borderRadius: BorderRadius.circular(8 * sdp),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Row(
                children: [
                  Expanded(child: child),
                  if (selected)
                    Padding(
                      padding: EdgeInsets.only(left: 8 * sdp, right: 4 * sdp),
                      child: const Icon(
                        Icons.check_circle,
                        color: DocColors.primary,
                        size: 24,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails({required this.account, required this.sdp});
  final AccountOption account;
  final double sdp;

  @override
  Widget build(BuildContext context) {
    final doctor = account.role == AccountRole.doctor;
    return Padding(
      padding: EdgeInsets.all(10 * sdp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            doctor
                ? account.doctorName
                : '${account.adminFirstName} ${account.adminLastName}',
            textScaler: TextScaler.noScaling,
            style: _selectionText(
              'OpenSans',
              13 * sdp,
              color: DocColors.greenSea,
              weight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            doctor ? account.department : '(${account.adminUserName})',
            textScaler: TextScaler.noScaling,
            style: _selectionText(
              'OpenSans',
              10 * sdp,
              color: const Color(0xFF6C6E6F),
              weight: FontWeight.bold,
            ),
          ),
          if (doctor) ...[
            const SizedBox(height: 5),
            Text(
              account.doctorCode,
              textScaler: TextScaler.noScaling,
              style: _selectionText(
                'OpenSans',
                11 * sdp,
                color: Colors.black,
                weight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
