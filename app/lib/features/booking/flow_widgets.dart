import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/booking_draft.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

const bookingSteps = 6;

/// Pops back to the date and time step, keeping the draft.
void backToWhen(BuildContext context) {
  Navigator.of(context)
      .popUntil((r) => r.settings.name == 'book-when' || r.isFirst);
}

/// Shared frame for the booking steps: header with progress, body, bottom action.
class FlowScaffold extends ConsumerWidget {
  const FlowScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.body,
    this.bottom,
  });

  final int step;
  final String title;
  final Widget body;
  final Widget? bottom;

  Future<void> _confirmExit(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.leaveBookingTitle),
        content: Text(l.leaveBookingBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.keepBooking),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.leave),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) {
      ref.read(bookingDraftProvider.notifier).reset();
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: StepHeader(
        step: step,
        total: bookingSteps,
        title: title,
        onClose: () => _confirmExit(context, ref),
      ),
      body: SafeArea(top: false, bottom: bottom == null, child: body),
      bottomNavigationBar: bottom,
    );
  }
}

/// One-line recap of the service and slot chosen so far.
class FlowSummary extends ConsumerWidget {
  const FlowSummary({super.key, this.showHours = false});
  final bool showHours;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final d = ref.watch(bookingDraftProvider);
    if (d.service == null) return const SizedBox.shrink();
    final parts = <String>[
      d.service!.name,
      if (d.hasSlot)
        whenLabel(DateTime(d.day!.year, d.day!.month, d.day!.day, d.hour!)),
      if (showHours && d.hours != null) l.hoursCount(d.hours!),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: CnSpace.md, vertical: 10),
      decoration: BoxDecoration(
        color: context.cn.sunken,
        borderRadius: BorderRadius.circular(CnSpace.radiusSm),
      ),
      child: Text(
        parts.join('  -  '),
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

String flowNoticeText(AppLocalizations l, FlowNotice n) => switch (n) {
  FlowNotice.noNurseFree => l.noticeNoNurseFree,
  FlowNotice.holdExpired => l.noticeHoldExpired,
  FlowNotice.paused => l.bookingsPausedBanner,
  FlowNotice.tooSoon => l.noticeTooSoon,
  FlowNotice.tooFar => l.noticeTooFar,
  FlowNotice.crossesMidnight => l.noticeCrossesMidnight,
  FlowNotice.other => l.errorGeneric,
};
