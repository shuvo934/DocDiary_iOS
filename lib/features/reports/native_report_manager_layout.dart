import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import 'report_manager_menu.dart';

/// The native ReportManager menu only chooses a report; it has no API request.
/// ReportView owns parameters and results and is connected in the next step.
class NativeReportManagerLayout extends StatelessWidget {
  const NativeReportManagerLayout({
    super.key,
    required this.centerApi,
    required this.onBack,
    required this.onReport,
  });

  final Uri centerApi;
  final VoidCallback onBack;
  final ValueChanged<ReportManagerItem> onReport;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.shortestSide;
    final sdp = width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
    final headerHeight = math.max(
      56.0,
      (media.size.height - media.padding.vertical) * .09,
    );
    final items = nativeReportManagerItems(centerApi);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: DocColors.primary,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [DocColors.muted, DocColors.primary, DocColors.primary],
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
                              key: const Key('report_manager_back'),
                              tooltip: 'Back',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: onBack,
                              color: Colors.white,
                              icon: Icon(
                                Icons.arrow_back_ios_new,
                                size: 19 * sdp,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Report Manager',
                              key: const Key('report_manager_title'),
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
                        child: LayoutBuilder(
                          builder:
                              (context, constraints) => SingleChildScrollView(
                                key: const Key('report_manager_scroll'),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final item in items)
                                        _ReportButton(
                                          item: item,
                                          sdp: sdp,
                                          onTap: () => onReport(item),
                                        ),
                                    ],
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
    );
  }
}

class _ReportButton extends StatelessWidget {
  const _ReportButton({
    required this.item,
    required this.sdp,
    required this.onTap,
  });

  final ReportManagerItem item;
  final double sdp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8 * sdp);
    return Padding(
      padding: EdgeInsets.only(
        top: 10 * sdp,
        bottom: 10 * sdp,
        left: 15 * sdp,
        right: 15 * sdp,
      ),
      child: Material(
        key: Key('report_manager_card_${item.nativeType}'),
        color: DocColors.greenSea,
        elevation: 2 * sdp,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: 150 * sdp,
              child: ExcludeSemantics(
                child: Image.asset(
                  'assets/images/med_background_1.png',
                  fit: BoxFit.fill,
                  color: DocColors.primary,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: Semantics(
                button: true,
                child: InkWell(
                  key: Key('report_manager_select_${item.nativeType}'),
                  borderRadius: radius,
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: 50 * sdp),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(10 * sdp),
                        child: Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12 * sdp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.5,
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
