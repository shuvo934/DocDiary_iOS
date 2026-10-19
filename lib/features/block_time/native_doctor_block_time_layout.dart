import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/native_dates.dart';
import '../dashboard/native_dashboard_icons.dart';
import 'doctor_block_time_models.dart';

class NativeDoctorBlockTimeLayout extends StatefulWidget {
  const NativeDoctorBlockTimeLayout({
    super.key,
    required this.window,
    required this.today,
    required this.calendar,
    required this.loading,
    required this.onBack,
    required this.onDay,
  });
  final DoctorBlockWindow window;
  final DateTime today;
  final DoctorBlockCalendar? calendar;
  final bool loading;
  final VoidCallback onBack;
  final ValueChanged<DoctorBlockedDay> onDay;
  @override
  State<NativeDoctorBlockTimeLayout> createState() =>
      _NativeDoctorBlockTimeLayoutState();
}

class _NativeDoctorBlockTimeLayoutState
    extends State<NativeDoctorBlockTimeLayout> {
  final _pages = PageController();
  int _page = 0;
  @override
  void didUpdateWidget(covariant NativeDoctorBlockTimeLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.window.first != widget.window.first) {
      final visible = oldWidget.window.month(_page);
      _page = ((visible.year - widget.window.first.year) * 12 +
              visible.month -
              widget.window.first.month)
          .clamp(0, 2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) {
          _pages.jumpToPage(_page);
        }
      });
    }
  }

  void _move(int delta) {
    if (!widget.loading && _pages.hasClients) {
      _pages.jumpToPage((_page + delta).clamp(0, 2));
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context),
        width = MediaQuery.sizeOf(context).shortestSide;
    final sdp = width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
    final labelHeight = math.max(30.0, media.textScaler.scale(14) * 1.35 + 4);
    final rowHeight = labelHeight + 28.5, month = widget.window.month(_page);
    final headerHeight = math.max(
      56.0,
      (media.size.height - media.padding.vertical) * .09,
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
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: headerHeight),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12 * sdp, 4, 5, 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 19 * sdp,
                            height: 44,
                            child: IconButton(
                              key: const Key('block_time_back'),
                              tooltip: 'Back',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: widget.loading ? null : widget.onBack,
                              disabledColor: Colors.white,
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
                              'Block Time (Schedule)',
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
                          child: Column(
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 56,
                                ),
                                child: Row(
                                  children: [
                                    _monthButton(false),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          '${blockTimeMonths[month.month - 1].toUpperCase()}  ${month.year}',
                                          key: const Key('block_time_month'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: DocColors.primary,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                    _monthButton(true),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: math.max(
                                  40.0,
                                  media.textScaler.scale(14) * 1.4 + 12,
                                ),
                                child: Row(
                                  children: [
                                    for (final w in const [6, 7, 1, 2, 3, 4, 5])
                                      Expanded(
                                        child: Center(
                                          child: Semantics(
                                            label: blockTimeWeekday(
                                              DateTime(2024, 1, w),
                                            ),
                                            excludeSemantics: true,
                                            child: Text(
                                              const [
                                                'M',
                                                'T',
                                                'W',
                                                'T',
                                                'F',
                                                'S',
                                                'S',
                                              ][w - 1],
                                              style: const TextStyle(
                                                fontFamily: 'Roboto',
                                                fontSize: 14,
                                                color: DocColors.greenSea,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  key: const Key('block_time_scroll'),
                                  child: SizedBox(
                                    height: 6 * rowHeight,
                                    child: PageView.builder(
                                      key: const Key('block_time_pages'),
                                      controller: _pages,
                                      physics:
                                          widget.loading
                                              ? const NeverScrollableScrollPhysics()
                                              : const ClampingScrollPhysics(),
                                      itemCount: 3,
                                      onPageChanged:
                                          (page) =>
                                              setState(() => _page = page),
                                      itemBuilder:
                                          (context, page) => _monthGrid(
                                            widget.window.month(page),
                                            labelHeight,
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
                ],
              ),
            ),
            if (widget.loading) ...[
              const ModalBarrier(dismissible: false, color: Colors.black54),
              const Center(child: _BlockTimeWait()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _monthButton(bool next) => SizedBox(
    width: 85,
    height: 56,
    child: IconButton(
      key: Key(next ? 'block_time_next' : 'block_time_previous'),
      tooltip: next ? 'Next month' : 'Previous month',
      onPressed:
          widget.loading || (next ? _page == 2 : _page == 0)
              ? null
              : () => _move(next ? 1 : -1),
      // Exact native library defaults: white arrows against the white header.
      // Preserve that appearance, along with accessible labels and swipe paging.
      color: Colors.white,
      disabledColor: Colors.white,
      icon: Icon(next ? Icons.chevron_right : Icons.chevron_left, size: 24),
    ),
  );
  Widget _monthGrid(DateTime month, double labelHeight) {
    final cells = blockTimeMonthCells(month);
    return Column(
      children: [
        for (var week = 0; week < 6; week++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _day(cells[week * 7 + col], month, labelHeight),
                ),
            ],
          ),
      ],
    );
  }

  Widget _day(DateTime date, DateTime month, double labelHeight) {
    final data = widget.calendar?.at(date),
        inMonth = date.month == month.month && widget.window.contains(date),
        today = date == dateOnly(widget.today);
    final color =
        !inMonth
            ? const Color(0x1F000000)
            : today
            ? DocColors.primary
            : data != null
            ? const Color(0xFFFDA000)
            : date.weekday == DateTime.friday
            ? const Color(0xFFC23616)
            : DocColors.muted;
    final description =
        data == null ? '' : ', ${data.message ?? 'Blocked Schedule'}';
    final suffix = '${blockTimeDateKey(month)}_${blockTimeDateKey(date)}';
    return Semantics(
      key: Key('block_time_cell_$suffix'),
      label:
          '${blockTimeDateLabel(date)}, ${blockTimeWeekday(date)}$description',
      button: data != null,
      enabled: data != null && !widget.loading,
      excludeSemantics: true,
      child: InkWell(
        onTap: data == null || widget.loading ? null : () => widget.onDay(data),
        child: Column(
          children: [
            const SizedBox(height: 4),
            SizedBox(
              height: labelHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${date.day}',
                      key: Key('block_time_label_$suffix'),
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 20,
              child:
                  data == null
                      ? null
                      : Opacity(
                        opacity: inMonth ? 1 : .12,
                        child: NativeDashboardIcon(
                          NativeDashboardGlyph.leave,
                          key: Key('block_time_icon_$suffix'),
                          size: 20,
                          color:
                              data.fullDay || data.allSchedulesBlocked
                                  ? const Color(0xFFCC0000)
                                  : const Color(0xFF1DD1A1),
                        ),
                      ),
            ),
            const SizedBox(height: 2),
            const SizedBox(
              height: .5,
              child: ColoredBox(
                color: Color(0x1F000000),
                child: SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NativeDoctorBlockTimeSheet extends StatelessWidget {
  const NativeDoctorBlockTimeSheet({super.key, required this.day});
  final DoctorBlockedDay day;
  @override
  Widget build(BuildContext context) {
    final sdp = widthScale(MediaQuery.sizeOf(context).shortestSide);
    TextStyle text(double size, [Color color = Colors.black]) => TextStyle(
      fontFamily: 'Poppins',
      fontSize: size * sdp,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.5,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Material(
          key: const Key('block_time_sheet'),
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              key: const Key('block_time_sheet_scroll'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ColoredBox(
                    color: DocColors.primary,
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          day.title,
                          textAlign: TextAlign.center,
                          style: text(16, Colors.white),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(7, 7, 7, 0),
                    child: Text(
                      blockTimeDateLabel(day.date),
                      textAlign: TextAlign.center,
                      style: text(13),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(7, 0, 7, 7),
                    child: Text(
                      blockTimeWeekday(day.date),
                      textAlign: TextAlign.center,
                      style: text(13),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10 * sdp),
                    child:
                        day.message != null
                            ? Text(
                              day.message!,
                              textAlign: TextAlign.center,
                              style: text(12, Colors.black54),
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < day.slots.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 1.0,
                                    ),
                                    child: Text(
                                      day.slots[i].time,
                                      key: Key('block_time_slot_$i'),
                                      textAlign: TextAlign.center,
                                      style: text(12, Colors.black54),
                                    ),
                                  ),
                              ],
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

  static double widthScale(double width) =>
      width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
}

class _BlockTimeWait extends StatefulWidget {
  const _BlockTimeWait();
  @override
  State<_BlockTimeWait> createState() => _BlockTimeWaitState();
}

class _BlockTimeWaitState extends State<_BlockTimeWait>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  )..repeat();
  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('block_time_loading'),
    label: 'Loading blocked schedules',
    liveRegion: true,
    child: SizedBox(
      width: math.min(MediaQuery.sizeOf(context).width - 48, 300),
      height: 40,
      child: AnimatedBuilder(
        animation: _animation,
        builder:
            (context, _) =>
                CustomPaint(painter: _BlockTimeDots(_animation.value)),
      ),
    ),
  );
}

class _BlockTimeDots extends CustomPainter {
  const _BlockTimeDots(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 5; i++) {
      final phase = (progress - i * 100 / 2300) % 1;
      canvas.drawCircle(
        Offset(
          4 + (size.width - 8) * Curves.easeInOut.transform(phase),
          size.height / 2,
        ),
        3.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BlockTimeDots old) => old.progress != progress;
}
