import 'package:flutter/widgets.dart';

import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';

sealed class PaymentOutcome {
  const PaymentOutcome();
}

/// Payment verified; [booking] is the booking as returned by /payments/verify.
class PaymentPaid extends PaymentOutcome {
  const PaymentPaid(this.booking);
  final Booking booking;
}

/// The user closed the checkout without paying.
class PaymentDismissed extends PaymentOutcome {
  const PaymentDismissed();
}

/// The gateway reported a failure ([message] may be null).
class PaymentFailed extends PaymentOutcome {
  const PaymentFailed([this.message]);
  final String? message;
}

/// The hold ran out while the checkout was open.
class PaymentTimedOut extends PaymentOutcome {
  const PaymentTimedOut();
}

class PaymentRequest {
  const PaymentRequest({required this.booking, required this.order, required this.payments, this.phone, this.name});
  final Booking booking;
  final OrderOut order;
  final PaymentRepository payments;
  final String? phone;
  final String? name;
}

abstract class PaymentLauncher {
  /// Runs checkout, then verifies with the backend. Verify/network errors
  /// are thrown as ApiException so the caller can handle them.
  Future<PaymentOutcome> pay(BuildContext context, PaymentRequest request);
}

/// Chooses the launcher by the gateway named in the order.
class RoutingPaymentLauncher implements PaymentLauncher {
  const RoutingPaymentLauncher({required this.fake, required this.razorpay});
  final PaymentLauncher fake;
  final PaymentLauncher razorpay;

  @override
  Future<PaymentOutcome> pay(BuildContext context, PaymentRequest request) =>
      (request.order.gateway == 'razorpay' ? razorpay : fake).pay(context, request);
}
