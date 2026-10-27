import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/async_body.dart';
import '../../ui/status.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.myBookings),
          bottom: TabBar(
            tabs: [
              Tab(text: l.tabCurrent),
              Tab(text: l.tabHistory),
            ],
            labelStyle: Theme.of(context).textTheme.labelLarge,
            indicatorColor: context.cn.accent,
            labelColor: context.cn.accentText,
            unselectedLabelColor: context.cn.muted,
          ),
        ),
        body: const TabBarView(
          children: [
            _BookingsList(current: true),
            _BookingsList(current: false),
          ],
        ),
      ),
    );
  }
}

class _BookingsList extends ConsumerWidget {
  const _BookingsList({required this.current});
  final bool current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final value = ref.watch(bookingsProvider(current));
    return AsyncBody<List<Booking>>(
      value: value,
      onRefresh: () async {
        ref.invalidate(bookingsProvider(current));
        await ref
            .read(bookingsProvider(current).future)
            .catchError((_) => <Booking>[]);
      },
      isEmpty: (l) => l.isEmpty,
      emptyIcon: Icons.event_note_outlined,
      emptyTitle: current ? l.noCurrentBookings : l.noHistory,
      emptyBody: current ? l.noCurrentBookingsBody : l.noHistoryBody,
      emptyAction: current ? l.bookAService : null,
      onEmptyAction: () => context.go('/services'),
      builder: (context, list) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: CnSpace.page,
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: CnSpace.sm),
        itemBuilder: (_, i) => BookingCard(booking: list[i]),
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = context.cn;
    final status = bookingStatusLabel(l, booking.status);
    final sub = [
      whenLabel(booking.slotStart),
      if (booking.nurseName != null) booking.nurseName!,
    ].join(', ');
    return CnCard(
      onTap: () => context.push('/bookings/${booking.id}'),
      semanticLabel: '${booking.serviceName}, $sub, $status',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.serviceName,
                  style: t.titleSmall?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(sub, style: t.bodyMedium?.copyWith(color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: CnSpace.sm),
          StatusChip(label: status, tone: bookingStatusTone(booking.status)),
        ],
      ),
    );
  }
}
