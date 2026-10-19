import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';

class NativeDoctorPasswordLayout extends StatefulWidget {
  const NativeDoctorPasswordLayout({
    super.key,
    required this.loading,
    required this.current,
    required this.next,
    required this.confirm,
    required this.currentFocus,
    required this.nextFocus,
    required this.confirmFocus,
    required this.currentHelper,
    required this.nextHelper,
    required this.confirmHelper,
    required this.onCurrentChanged,
    required this.onNextChanged,
    required this.onConfirmChanged,
    required this.onClose,
    required this.onUpdate,
  });
  final bool loading;
  final TextEditingController current, next, confirm;
  final FocusNode currentFocus, nextFocus, confirmFocus;
  final String? currentHelper, nextHelper, confirmHelper;
  final ValueChanged<String> onCurrentChanged, onNextChanged, onConfirmChanged;
  final VoidCallback onClose, onUpdate;
  @override
  State<NativeDoctorPasswordLayout> createState() =>
      _NativeDoctorPasswordLayoutState();
}

class _NativeDoctorPasswordLayoutState
    extends State<NativeDoctorPasswordLayout> {
  final _visible = [false, false, false];

  InputDecoration _decoration(String label, String? helper) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 15, color: Color(0xFFB2BEC3)),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          fontSize: 15,
          color:
              states.contains(WidgetState.focused)
                  ? DocColors.greenSea
                  : const Color(0xFFB2BEC3),
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(const Color(0xFF9E9E9E), 1),
      enabledBorder: border(const Color(0xFF9E9E9E), 1),
      focusedBorder: border(DocColors.greenSea, 2),
      helperText: helper == null || helper.isEmpty ? null : helper,
      helperMaxLines: 5,
      helperStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 11,
        color: Color(0xFFCC0000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).shortestSide;
    final sdp = width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
    Widget field(
      int index,
      String name,
      String label,
      TextEditingController controller,
      FocusNode focus,
      String? helper,
      ValueChanged<String> changed,
    ) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: TextField(
        key: Key('password_$name'),
        controller: controller,
        focusNode: focus,
        style: const TextStyle(
          fontFamily: 'OpenSans',
          fontSize: 15,
          color: Colors.black,
          height: 1.5,
        ),
        cursorColor: DocColors.greenSea,
        obscureText: !_visible[index],
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        autofillHints: [
          index == 0 ? AutofillHints.password : AutofillHints.newPassword,
        ],
        decoration: _decoration(label, helper).copyWith(
          suffixIcon: IconButton(
            key: Key('password_toggle_$name'),
            tooltip:
                '${_visible[index] ? 'Hide' : 'Show'} ${label.toLowerCase()}',
            color: DocColors.muted,
            onPressed: () => setState(() => _visible[index] = !_visible[index]),
            icon: Icon(
              _visible[index] ? Icons.visibility : Icons.visibility_off,
            ),
          ),
        ),
        onChanged: changed,
        onSubmitted: (_) => focus.unfocus(),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: DocColors.clouds,
      ),
      child: Scaffold(
        key: const Key('doctor_password_screen'),
        backgroundColor: DocColors.clouds,
        body: SafeArea(
          bottom: false,
          child: ColoredBox(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child:
                  widget.loading
                      ? const Center(
                        child: CircularProgressIndicator(
                          key: Key('password_loading'),
                          color: DocColors.primary,
                        ),
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ColoredBox(
                            color: DocColors.clouds,
                            child: Padding(
                              padding: EdgeInsets.all(12 * sdp),
                              child: Row(
                                children: [
                                  SizedBox.square(
                                    dimension: 21 * sdp,
                                    child: IconButton(
                                      key: const Key('password_close'),
                                      tooltip: 'Close',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: widget.onClose,
                                      icon: Icon(
                                        Icons.close,
                                        size: 21 * sdp,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Change Password',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13 * sdp,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 1,
                            child: ColoredBox(color: DocColors.greenSea),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              key: const Key('password_scroll'),
                              padding: EdgeInsets.all(4 * sdp),
                              child: AutofillGroup(
                                onDisposeAction: AutofillContextAction.cancel,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    field(
                                      0,
                                      'current',
                                      'Current Password',
                                      widget.current,
                                      widget.currentFocus,
                                      widget.currentHelper,
                                      widget.onCurrentChanged,
                                    ),
                                    field(
                                      1,
                                      'new',
                                      'New Password',
                                      widget.next,
                                      widget.nextFocus,
                                      widget.nextHelper,
                                      widget.onNextChanged,
                                    ),
                                    field(
                                      2,
                                      'confirm',
                                      'Confirm Password',
                                      widget.confirm,
                                      widget.confirmFocus,
                                      widget.confirmHelper,
                                      widget.onConfirmChanged,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Material(
                              color: DocColors.primary,
                              elevation: 2,
                              borderRadius: BorderRadius.circular(10),
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: const LinearGradient(
                                    colors: [
                                      DocColors.primary,
                                      DocColors.greenSea,
                                    ],
                                  ),
                                ),
                                child: InkWell(
                                  key: const Key('password_update'),
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: widget.onUpdate,
                                  child: Semantics(
                                    button: true,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(7),
                                        child: Center(
                                          child: Text(
                                            'UPDATE',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13 * sdp,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
