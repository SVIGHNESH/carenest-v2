import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/payment/payment_launcher.dart';
import '../../state/auth_controller.dart';
import '../../state/booking_draft.dart';
import '../../state/providers.dart';
import '../../ui/error_text.dart';
import '../../ui/status.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'flow_widgets.dart';

/// Step 6: review, then create the booking and pay.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  bool _busy = false;
  String? _error;

  BookingRequest _request(BookingDraft d) => BookingRequest(
    serviceId: d.service!.id,
    day: d.day!,
    hour: d.hour!,
    hours: d.hours!,
    nurseGender: d.gender!,
    addressId: d.address!.id,
    patientName: d.patientName,
    contactPhone: d.contactPhone,
    memberId: d.member?.id,
    patientAge: d.patientAge,
    patientSex: d.patientSex,
    patientCondition: d.condition,
  );

  /// Sends the user back to the date and time step with a message.
  void _backWithNotice(FlowNotice notice) {
    ref.read(bookingDraftProvider.notifier).setCreatedBooking(null);
    ref.read(flowNoticeProvider.notifier).show(notice);
    ref.invalidate(timeGridProvider);
    backToWhen(context);
  }

  bool _holdValid(Booking? b) =>
      b != null &&
      b.status == 'pending_payment' &&
      b.holdExpiresAt != null &&
      b.holdExpiresAt!.isAfter(DateTime.now().toUtc());

  Future<void> _pay() async {
    final l = AppLocalizations.of(context);
    final draft = ref.read(bookingDraftProvider);
    final bookings = ref.read(bookingRepositoryProvider);
    final payments = ref.read(paymentRepositoryProvider);
    final launcher = ref.read(paymentLauncherProvider);
    final user = ref.read(authControllerProvider).user;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final held = draft.createdBooking;
      final Booking booking;
      if (_holdValid(held)) {
        booking = held!;
      } else {
        booking = await bookings.create(_request(draft));
        ref.read(bookingDraftProvider.notifier).setCreatedBooking(booking);
      }
      final order = await payments.createOrder(booking.id);
      if (!mounted) return;
      final outcome = await launcher.pay(
        context,
        PaymentRequest(
          booking: booking,
          order: order,
          payments: payments,
          phone: user?.phone,
          name: user?.name,
        ),
      );
      if (!mounted) return;
      switch (outcome) {
        case PaymentPaid(:final booking):
          await _afterPaid(booking);
        case PaymentDismissed():
          messenger.showSnackBar(
            SnackBar(content: Text(l.paymentNotCompleted)),
          );
        case PaymentFailed(:final message):
          setState(() => _error = message ?? l.paymentFailed);
        case PaymentTimedOut():
          _backWithNotice(FlowNotice.holdExpired);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      final notice = flowNoticeForCode(e.code);
      if (notice != null) {
        _backWithNotice(notice);
      } else {
        setState(() => _error = errorMessage(context, e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _afterPaid(Booking booking) async {
    final ctl = ref.read(bookingDraftProvider.notifier);
    ref.invalidate(bookingsProvider);
    if (booking.status == 'cancelled') {
      // Paid after the hold ran out and no nurse was left: refunded automatically.
      ctl.reset();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(ctx).autoCancelledTitle),
          content: Text(
            AppLocalizations.of(ctx).autoCancelledBody(rupees(booking.amount)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(ctx).ok),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.go('/home');
      context.push('/bookings/${booking.id}');
      return;
    }
    ctl.reset();
    context.go('/book/confirmed/${booking.id}', extra: booking);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = context.cn;
    final d = ref.watch(bookingDraftProvider);
    if (d.service == null ||
        !d.hasSlot ||
        d.hours == null ||
        d.gender == null ||
        d.address == null) {
      return FlowScaffold(
        step: 6,
        title: l.stepReviewTitle,
        body: Center(
          child: CnButton(
            label: l.startOver,
            expand: false,
            onPressed: () => context.go('/home'),
          ),
        ),
      );
    }
    final quote = ref.watch(
      quoteProvider((serviceId: d.service!.id, hours: d.hours!)),
    );
    final start = DateTime(d.day!.year, d.day!.month, d.day!.day, d.hour!);
    final end = start.add(Duration(hours: d.hours!));
    final amount = quote.asData?.value.amount;
    final a = d.address!;

    return FlowScaffold(
      step: 6,
      title: l.stepReviewTitle,
      bottom: BottomActionBar(
        note: l.confirmedWhenPaid,
        child: CnButton(
          label: amount == null ? l.pay : l.payAmount(rupees(amount)),
          onPressed: amount == null ? null : _pay,
          loading: _busy,
        ),
      ),
      body: ListView(
        padding: CnSpace.page,
        children: [
          CnCard(
            child: Column(
              children: [
                DetailRow(label: l.service, value: d.service!.name),
                const Divider(),
                DetailRow(
                  label: l.when,
                  value: '${whenLabel(start)}\n${timeRangeLabel(start, end)}',
                ),
                const Divider(),
                DetailRow(label: l.duration, value: l.hoursCount(d.hours!)),
                const Divider(),
                DetailRow(
                  label: l.nurse,
                  value: l.nurseGenderLine(genderLabel(l, d.gender!)),
                ),
                const Divider(),
                DetailRow(
                  label: l.patient,
                  value: [
                    d.patientName,
                    if (d.patientAge != null) '${d.patientAge}',
                  ].join(', '),
                ),
                const Divider(),
                DetailRow(label: l.contactPhone, value: d.contactPhone),
                const Divider(),
                DetailRow(
                  label: l.address,
                  value:
                      a.summary +
                      ((a.landmark ?? '').isNotEmpty ? '\n${a.landmark}' : ''),
                ),
              ],
            ),
          ),
          const SizedBox(height: CnSpace.lg),
          CnCard(
            color: c.accentSoft,
            child: quote.when(
              loading: () => const SizedBox(height: 32, child: CnLoading()),
              error: (e, _) => Row(
                children: [
                  Expanded(child: Text(errorMessage(context, e))),
                  CnButton(
                    label: l.tryAgain,
                    kind: CnButtonKind.text,
                    expand: false,
                    onPressed: () => ref.invalidate(quoteProvider),
                  ),
                ],
              ),
              data: (q) => Semantics(
                container: true,
                label: '${l.total}: ${rupees(q.amount)}',
                excludeSemantics: true,
                child: Row(
                  children: [
                    Expanded(child: Text(l.total, style: t.titleMedium)),
                    Text(
                      rupees(q.amount),
                      style: t.headlineMedium?.copyWith(color: c.accentText),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: CnSpace.md),
          Text(l.holdNote, style: t.bodySmall),
          if (_error != null) ...[
            const SizedBox(height: CnSpace.lg),
            CnBanner(message: _error!, tone: Tone.danger),
          ],
        ],
      ),
    );
  }
}
