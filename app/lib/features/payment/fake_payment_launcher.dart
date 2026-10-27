import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/payment/payment_launcher.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// Stand-in for Razorpay while the backend runs its fake gateway.
class FakePaymentLauncher implements PaymentLauncher {
  const FakePaymentLauncher();

  @override
  Future<PaymentOutcome> pay(
    BuildContext context,
    PaymentRequest request,
  ) async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      showDragHandle: true,
      builder: (_) => FakePaymentSheet(request: request),
    );
    if (result is PaymentOutcome) return result;
    if (result is Exception) throw result;
    return const PaymentDismissed();
  }
}

enum _Method { upi, card, netbanking }

class FakePaymentSheet extends StatefulWidget {
  const FakePaymentSheet({super.key, required this.request, this.clock});
  final PaymentRequest request;
  final DateTime Function()? clock;

  @override
  State<FakePaymentSheet> createState() => _FakePaymentSheetState();
}

class _FakePaymentSheetState extends State<FakePaymentSheet> {
  _Method _method = _Method.upi;
  bool _busy = false;
  Timer? _timer;
  Duration? _left;

  DateTime _now() => (widget.clock ?? DateTime.now)().toUtc();

  @override
  void initState() {
    super.initState();
    _tick();
    if (widget.request.booking.holdExpiresAt != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    final end = widget.request.booking.holdExpiresAt;
    if (end == null) return;
    final left = end.difference(_now());
    if (left <= Duration.zero) {
      _timer?.cancel();
      if (mounted && !_busy) Navigator.of(context).pop(const PaymentTimedOut());
      return;
    }
    if (mounted) setState(() => _left = left);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    final r = widget.request;
    try {
      final fake = await r.payments.fakePay(r.booking.id, r.order.orderId);
      final booking = await r.payments.verify(
        bookingId: r.booking.id,
        orderId: r.order.orderId,
        paymentId: fake.paymentId,
        signature: fake.signature,
      );
      if (mounted) Navigator.of(context).pop(PaymentPaid(booking));
    } on Exception catch (e) {
      if (mounted) Navigator.of(context).pop(e);
    }
  }

  String _mmss(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.cn;
    final t = Theme.of(context).textTheme;
    final amount = rupees(widget.request.order.amount);
    final rows = <(_Method, String, String, IconData)>[
      (
        _Method.upi,
        l.payUpi,
        l.payUpiHint,
        Icons.account_balance_wallet_outlined,
      ),
      (_Method.card, l.payCard, l.payCardHint, Icons.credit_card),
      (
        _Method.netbanking,
        l.payNetbanking,
        l.payNetbankingHint,
        Icons.account_balance_outlined,
      ),
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(l.appName, style: t.titleLarge)),
                Text(amount, style: t.titleLarge),
              ],
            ),
            if (_left != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Semantics(
                  label: l.holdTimeLeftSemantics(_left!.inMinutes + 1),
                  child: ExcludeSemantics(
                    child: Text(
                      l.holdTimeLeft(_mmss(_left!)),
                      style: t.bodySmall,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: CnSpace.lg),
            for (final r in rows) ...[
              SelectTile(
                title: r.$2,
                subtitle: r.$3,
                leading: Icon(r.$4, color: c.fg2),
                selected: _method == r.$1,
                onTap: _busy ? null : () => setState(() => _method = r.$1),
              ),
              const SizedBox(height: CnSpace.sm),
            ],
            const SizedBox(height: CnSpace.sm),
            CnButton(
              label: l.payAmount(amount),
              onPressed: _pay,
              loading: _busy,
            ),
            const SizedBox(height: CnSpace.md),
            Text(
              l.paySecureTestNote,
              style: t.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
