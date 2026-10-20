import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import 'management_access.dart';

class NativeManagementPortalLayout extends StatelessWidget {
  const NativeManagementPortalLayout({
    super.key,
    required this.title,
    required this.destinations,
    required this.onBack,
    required this.onDestination,
    this.loading = false,
    this.message,
  });

  final String title;
  final List<ManagementDestination> destinations;
  final VoidCallback onBack;
  final ValueChanged<ManagementDestination> onDestination;
  final bool loading;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.shortestSide;
    final sdp = width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
    final headerHeight = math.max(
      56.0,
      (media.size.height - media.padding.vertical) * .09,
    );
    Widget row(List<ManagementDestination> entries) => Padding(
      padding: EdgeInsets.only(top: 8 * sdp, left: 4 * sdp, right: 4 * sdp),
      child:
          entries.isEmpty
              ? const SizedBox.shrink()
              : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in entries)
                      Expanded(
                        child: _PortalCard(
                          destination: entry,
                          sdp: sdp,
                          onTap: () => onDestination(entry),
                        ),
                      ),
                  ],
                ),
              ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: DocColors.primary,
        body: Stack(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    DocColors.muted,
                    DocColors.primary,
                    DocColors.primary,
                  ],
                  stops: [0, .7, 1],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    ColoredBox(
                      color: DocColors.primary,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: headerHeight),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(12 * sdp, 4, 5, 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 19 * sdp,
                                height: 44,
                                child: IconButton(
                                  key: const Key('management_back'),
                                  tooltip: 'Back',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: loading ? null : onBack,
                                  color: Colors.white,
                                  disabledColor: Colors.white,
                                  icon: Icon(
                                    Icons.arrow_back_ios_new,
                                    size: 19 * sdp,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  title,
                                  key: const Key('management_title'),
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14 * sdp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                        child: ColoredBox(
                          color: Colors.white,
                          child: SafeArea(
                            top: false,
                            child:
                                message != null
                                    ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                          message!,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    )
                                    : SingleChildScrollView(
                                      key: const Key('management_scroll'),
                                      child:
                                          loading
                                              ? const SizedBox.shrink()
                                              : Column(
                                                children: [
                                                  row(
                                                    destinations
                                                        .where(
                                                          (e) =>
                                                              e ==
                                                                  ManagementDestination
                                                                      .humanResources ||
                                                              e ==
                                                                  ManagementDestination
                                                                      .accounts,
                                                        )
                                                        .toList(),
                                                  ),
                                                  row(
                                                    destinations
                                                        .where(
                                                          (e) =>
                                                              e ==
                                                                  ManagementDestination
                                                                      .analytics ||
                                                              e ==
                                                                  ManagementDestination
                                                                      .reports,
                                                        )
                                                        .toList(),
                                                  ),
                                                ],
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
            if (loading) ...[
              const ModalBarrier(dismissible: false, color: Colors.black54),
              const Center(
                child: CircularProgressIndicator(
                  key: Key('management_loading'),
                  color: DocColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  const _PortalCard({
    required this.destination,
    required this.sdp,
    required this.onTap,
  });
  final ManagementDestination destination;
  final double sdp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8 * sdp);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * sdp, vertical: 12 * sdp),
      child: Material(
        color: Colors.white,
        elevation: 5 * sdp,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: DocColors.greenSea),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical:
                        (destination == ManagementDestination.accounts
                            ? 10
                            : 8) *
                        sdp,
                  ),
                  child: Opacity(
                    opacity: .07,
                    child: Image.asset(
                      'assets/images/${destination.artwork}',
                      fit: BoxFit.contain,
                      color: DocColors.primary,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: Semantics(
                button: true,
                child: InkWell(
                  key: Key('management_${destination.name}'),
                  borderRadius: radius,
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: 100 * sdp),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(7 + 12 * sdp),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4 * sdp),
                          child: Text(
                            destination.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11 * sdp,
                              fontWeight: FontWeight.w700,
                              color: DocColors.greenSea,
                              height: 1.5,
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
    );
  }
}
