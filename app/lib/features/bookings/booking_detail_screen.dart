import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/models/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/booking_draft.dart';
import '../../state/providers.dart';
import '../../ui/async_body.dart';
import '../../ui/status.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../home/service_detail_screen.dart';

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.bookingId});
  final int bookingId;

  Future<void> _call(BuildContext context, WidgetRef ref, String phone) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(uriLauncherProvider)(
      Uri(scheme: 'tel', path: phone.replaceAll(' ', '')),
    );
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.couldNotOpenDialer(phone))),
      );
    }
  }

  Future<void> _bookAgain(
    BuildContext context,
    WidgetRef ref,
    Booking b,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final s = await ref.read(serviceProvider(b.serviceId).future);
      final paused = await ref
          .read(bookingSettingsProvider.future)
          .then((s) => s.bookingsPaused, onError: (_) => false);
      if (!s.available || paused) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(paused ? l.bookingsPausedBanner : l.notAvailableNow),
          ),
        );
        return;
      }
      ref.read(bookingDraftProvider.notifier).start(s);
      if (context.mounted) context.push('/book/patient');
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorGeneric)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final value = ref.watch(bookingProvider(bookingId));
    return Scaffold(
      appBar: AppBar(title: Text(l.bookingNumber(bookingId))),
      body: AsyncBody<Booking>(
        value: value,
        onRefresh: () async {
          ref.invalidate(bookingProvider(bookingId));
          await ref
              .read(bookingProvider(bookingId).future)
              .then((_) {}, onError: (_) {});
        },
        builder: (context, b) => _Detail(
          booking: b,
          onCall: () => _call(context, ref, b.supportPhone),
          onBookAgain: () => _bookAgain(context, ref, b),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.booking,
    required this.onCall,
    required this.onBookAgain,
  });
  final Booking booking;
  final VoidCallback onCall;
  final VoidCallback onBookAgain;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final b = booking;
    final start = b.slotStart;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: CnSpace.page,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(
            label: bookingStatusLabel(l, b.status),
            tone: bookingStatusTone(b.status),
          ),
        ),
        const SizedBox(height: CnSpace.lg),
        if (b.isCancelled) ...[
          CnCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.cancelledBy == 'user'
                      ? l.cancelledByYou
                      : l.cancelledByCareNest,
                  style: t.titleSmall,
                ),
                if ((b.cancelReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(l.cancelReason(b.cancelReason!), style: t.bodyMedium),
                ],
              ],
            ),
          ),
          const SizedBox(height: CnSpace.md),
          if (b.refund != null)
            CnCard(
              child: Column(
                children: [
                  DetailRow(label: l.refund, value: rupees(b.refund!.amount)),
                  const Divider(),
                  DetailRow(
                    label: l.refundStatus,
                    value: refundStatusLabel(l, b.refund!.status),
                  ),
                  if (!b.refund!.isSent) ...[
                    const Divider(),
                    DetailRow(
                      label: l.refundExpected,
                      value: b.refund!.expected ?? l.refundExpectedDefault,
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: CnSpace.md),
        ],
        CnCard(
          child: Column(
            children: [
              DetailRow(label: l.service, value: b.serviceName),
              if (!b.isCancelled || b.nurseName != null) ...[
                const Divider(),
                DetailRow(
                  label: l.nurse,
                  value: b.nurseName ?? l.nurseNotAssigned,
                ),
              ],
              const Divider(),
              DetailRow(label: l.when, value: whenLabel(start)),
              const Divider(),
              DetailRow(label: l.duration, value: l.hoursCount(b.hours)),
              const Divider(),
              DetailRow(
                label: l.patient,
                value: [
                  b.patientName,
                  if (b.patientAge != null) '${b.patientAge}',
                ].join(', '),
              ),
              const Divider(),
              DetailRow(
                label: l.address,
                value:
                    b.addressText +
                    ((b.addressLandmark ?? '').isNotEmpty
                        ? '\n${b.addressLandmark}'
                        : ''),
              ),
              const Divider(),
              DetailRow(
                label: l.amount,
                value: rupees(b.amount),
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: CnSpace.lg),
        if (b.isCancelled)
          CnButton(label: l.bookAgain, onPressed: onBookAgain)
        else ...[
          CnBanner(message: l.needChangeOrCancel(b.supportPhone)),
          const SizedBox(height: CnSpace.md),
          CnButton(
            label: l.callSupport,
            icon: Icons.call_outlined,
            kind: CnButtonKind.secondary,
            onPressed: onCall,
          ),
        ],
        const SizedBox(height: CnSpace.lg),
      ],
    );
  }
}
