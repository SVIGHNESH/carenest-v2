import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/models/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/async_body.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

class ConfirmedScreen extends ConsumerWidget {
  const ConfirmedScreen({super.key, required this.bookingId, this.initial});
  final int bookingId;
  final Booking? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final value = initial != null
        ? AsyncValue.data(initial!)
        : ref.watch(bookingProvider(bookingId));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        body: SafeArea(
          child: AsyncBody<Booking>(
            value: value,
            onRefresh: () async => ref.invalidate(bookingProvider(bookingId)),
            builder: (context, b) => _Content(booking: b),
          ),
        ),
        bottomNavigationBar: value.asData == null
            ? null
            : BottomActionBar(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CnButton(
                      label: l.viewBooking,
                      onPressed: () {
                        context.go('/bookings');
                        context.push('/bookings/$bookingId');
                      },
                    ),
                    const SizedBox(height: CnSpace.sm),
                    CnButton(
                      label: l.backToHome,
                      kind: CnButtonKind.text,
                      onPressed: () => context.go('/home'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.cn;
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: ExcludeSemantics(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: c.successSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: c.success, size: 48),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            l.bookingConfirmed,
            style: t.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l.bookingNumber(booking.id),
          style: t.bodyLarge?.copyWith(color: c.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        CnCard(
          child: Column(
            children: [
              DetailRow(
                label: l.yourNurse,
                value: booking.nurseName ?? l.nurseSoon,
              ),
              const Divider(),
              DetailRow(label: l.when, value: whenLabel(booking.slotStart)),
              const Divider(),
              DetailRow(
                label: l.paid,
                value: rupees(booking.amount),
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(l.smsSentNote, style: t.bodyMedium, textAlign: TextAlign.center),
      ],
    );
  }
}
