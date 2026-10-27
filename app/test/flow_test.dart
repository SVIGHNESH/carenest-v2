import 'package:carenest/data/api/api_exception.dart';
import 'package:carenest/state/booking_draft.dart';
import 'package:carenest/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

Future<void> tapText(WidgetTester t, String text, {bool settle = true}) async {
  final f = find.text(text);
  expect(f, findsWidgets, reason: 'looking for "$text"');
  await t.ensureVisible(f.first);
  await t.tap(f.first);
  settle ? await t.pumpAndSettle() : await t.pump();
}

Future<void> tapButton(WidgetTester t, String label) async {
  final f = find.widgetWithText(CnButton, label);
  expect(f, findsOneWidget, reason: 'button "$label"');
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Taps the review "Pay" button; the checkout sheet ticks every second, so do not wait for it to settle.
Future<void> tapPayOnReview(WidgetTester t) async {
  final f = find.widgetWithText(CnButton, 'Pay Rs 1,600');
  await t.ensureVisible(f);
  await t.tap(f);
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> tapPayInSheet(WidgetTester t) async {
  await t.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Pay Rs 1,600')));
  await t.pumpAndSettle();
}

/// Home -> service -> patient -> time -> hours -> nurse -> details -> review.
Future<void> walkToReview(WidgetTester t) async {
  await tapText(t, 'Elder care');
  await tapButton(t, 'Book now');
  await tapButton(t, 'Continue'); // patient: myself
  await tapText(t, '3:00 PM');
  await tapButton(t, 'Continue');
  await tapText(t, '4');
  await tapButton(t, 'Continue');
  await tapText(t, 'Female nurse');
  await tapButton(t, 'Continue');
  await tapButton(t, 'Continue'); // details prefilled, default address chosen
  expect(find.text('Review'), findsOneWidget);
}

void main() {
  testWidgets(
    'happy path ends on the confirmed screen and starts fresh afterwards',
    (t) async {
      final env = TestEnv();
      final container = await pumpApp(t, env);
      expect(find.text('Hello, Riya'), findsOneWidget);

      await walkToReview(t);
      expect(find.bySemanticsLabel('Nurse: Female nurse'), findsOneWidget);
      expect(
        find.text('Your booking is confirmed as soon as you pay.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(CnButton, 'Pay Rs 1,600'), findsOneWidget);

      await tapButton(t, 'Pay Rs 1,600');
      // The fake checkout sheet.
      expect(find.text('UPI'), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);
      expect(find.text('Net banking'), findsOneWidget);
      await t.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Pay Rs 1,600'),
        ),
      );
      await t.pumpAndSettle();

      final req = env.bookings.createRequests.single;
      expect(req.serviceId, 1);
      expect(req.hours, 4);
      expect(req.nurseGender, 'female');
      expect(req.addressId, 10);
      expect(req.toJson()['slot_start'], '2026-10-28T15:00:00');
      expect(req.contactPhone, '+919876543210');

      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(find.text('Anita S.'), findsOneWidget);
      expect(find.text('Rs 1,600'), findsOneWidget);
      expect(
        find.text('We have sent you an SMS with these details.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(CnButton, 'View booking'), findsOneWidget);
      // Draft was cleared.
      expect(container.read(bookingDraftProvider).service, isNull);
    },
  );

  Future<void> expectBackAtWhenWithChoices(
    WidgetTester t,
    ProviderContainer c,
    String notice,
  ) async {
    expect(find.text('Date and time'), findsOneWidget);
    expect(find.text(notice), findsOneWidget);
    final d = c.read(bookingDraftProvider);
    expect(d.hour, 15);
    expect(d.hours, 4);
    expect(d.gender, 'female');
    expect(d.createdBooking, isNull);
    // The slot is still selected, so Continue is enabled.
    final cont = t.widget<CnButton>(find.widgetWithText(CnButton, 'Continue'));
    expect(cont.onPressed, isNotNull);
  }

  testWidgets(
    'no_nurse_free on create returns to the time step and keeps choices',
    (t) async {
      final env = TestEnv();
      env.bookings.createError = const ApiException(
        kind: ApiErrorKind.conflict,
        status: 409,
        code: 'no_nurse_free',
        message: 'No nurse is free for that time. Please choose another time.',
      );
      final c = await pumpApp(t, env);
      await walkToReview(t);
      await tapButton(t, 'Pay Rs 1,600');
      await expectBackAtWhenWithChoices(
        t,
        c,
        'No nurse is free for that time any more. Please choose another time. Your other choices are kept.',
      );
      expect(env.payments.orders, isEmpty);
    },
  );

  testWidgets(
    'hold_expired at checkout returns to the time step and keeps choices',
    (t) async {
      final env = TestEnv();
      env.payments.orderError = const ApiException(
        kind: ApiErrorKind.conflict,
        status: 409,
        code: 'hold_expired',
        message:
            'This booking is no longer waiting for payment. Please book again.',
      );
      final c = await pumpApp(t, env);
      await walkToReview(t);
      await tapPayOnReview(t);
      await expectBackAtWhenWithChoices(
        t,
        c,
        'Your held time ran out. Please pick a time again. Your other choices are kept.',
      );
    },
  );

  testWidgets('paid but cancelled with refund shows an explanation', (t) async {
    final env = TestEnv();
    env.payments.finalStatus = 'cancelled';
    await pumpApp(t, env);
    await walkToReview(t);
    await tapPayOnReview(t);
    await tapPayInSheet(t);
    expect(find.text("We couldn't confirm your visit"), findsOneWidget);
    expect(
      find.textContaining('Rs 1,600 will be refunded in full'),
      findsOneWidget,
    );
  });

  testWidgets(
    'closing the payment sheet keeps the booking and allows paying again',
    (t) async {
      final env = TestEnv();
      await pumpApp(t, env);
      await walkToReview(t);
      await tapPayOnReview(t);
      await t.tapAt(const Offset(10, 10)); // dismiss the sheet
      await t.pumpAndSettle();
      expect(find.text('Review'), findsOneWidget);
      expect(find.textContaining('Payment was not completed'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      await tapPayOnReview(t);
      // The same held booking is reused, not created twice.
      expect(env.bookings.createRequests.length, 1);
      expect(env.payments.orders.length, 2);
    },
  );
}
