import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'payment_launcher.dart';

class RazorpayPaymentLauncher implements PaymentLauncher {
  const RazorpayPaymentLauncher();

  @override
  Future<PaymentOutcome> pay(
    BuildContext context,
    PaymentRequest request,
  ) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return const PaymentFailed(
        'Razorpay checkout is only available on a phone.',
      );
    }
    final razorpay = Razorpay();
    final done = Completer<PaymentOutcome>();
    final b = request.booking;

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (
      PaymentSuccessResponse r,
    ) async {
      try {
        final paid = await request.payments.verify(
          bookingId: b.id,
          orderId: r.orderId ?? request.order.orderId,
          paymentId: r.paymentId ?? '',
          signature: r.signature ?? '',
        );
        if (!done.isCompleted) done.complete(PaymentPaid(paid));
      } catch (e, st) {
        if (!done.isCompleted) done.completeError(e, st);
      }
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (done.isCompleted) return;
      done.complete(
        r.code == Razorpay.PAYMENT_CANCELLED
            ? const PaymentDismissed()
            : PaymentFailed(r.message),
      );
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});

    final left = b.holdExpiresAt?.difference(DateTime.now().toUtc()).inSeconds;
    razorpay.open({
      'key': request.order.keyId,
      'order_id': request.order.orderId,
      'amount': request.order.amount * 100,
      'currency': 'INR',
      'name': 'CareNest',
      'description': b.serviceName,
      if (left != null && left > 0) 'timeout': left,
      'prefill': {
        'contact': request.phone ?? b.contactPhone,
        'name': request.name ?? b.patientName,
      },
    });
    try {
      return await done.future;
    } finally {
      razorpay.clear();
    }
  }
}
