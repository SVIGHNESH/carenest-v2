import 'package:carenest/data/api/api_exception.dart';
import 'package:carenest/data/models/models.dart';
import 'package:carenest/features/bookings/booking_detail_screen.dart';
import 'package:carenest/features/profile/delete_account_screen.dart';
import 'package:carenest/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

void main() {
  testWidgets('confirmed booking has Call support and no cancel button', (
    t,
  ) async {
    final env = TestEnv();
    env.bookings.current = [
      makeBooking(status: 'confirmed', nurseName: 'Anita S.'),
    ];
    await pumpScreen(t, env, const BookingDetailScreen(bookingId: 1042));
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Anita S.'), findsOneWidget);
    expect(
      find.text('Need to change or cancel? Call support on 1800000000.'),
      findsOneWidget,
    );
    expect(
      find.textContaining(RegExp('cancel', caseSensitive: false)),
      findsOneWidget,
    ); // only the support sentence
    expect(find.widgetWithText(CnButton, 'Cancel booking'), findsNothing);
    await t.tap(find.widgetWithText(CnButton, 'Call support'));
    await t.pumpAndSettle();
    expect(env.launched.single.toString(), 'tel:1800000000');
  });

  testWidgets('cancelled booking shows reason, refund and Book again', (
    t,
  ) async {
    final env = TestEnv();
    env.bookings.history = [
      makeBooking(
        status: 'cancelled',
        cancelReason: 'The assigned nurse is unwell.',
        cancelledBy: 'admin',
        refund: const RefundOut(amount: 1600, status: 'refund_pending'),
      ),
    ];
    await pumpScreen(t, env, const BookingDetailScreen(bookingId: 1042));
    expect(find.text('Cancelled by CareNest'), findsOneWidget);
    expect(find.text('Reason: The assigned nurse is unwell.'), findsOneWidget);
    expect(find.text('Rs 1,600'), findsWidgets);
    expect(find.text('Refund in progress'), findsOneWidget);
    expect(find.text('5 to 7 working days'), findsOneWidget);
    await t.scrollUntilVisible(find.widgetWithText(CnButton, 'Book again'), 200);
    expect(find.widgetWithText(CnButton, 'Book again'), findsOneWidget);
    expect(find.widgetWithText(CnButton, 'Call support'), findsNothing);
  });

  testWidgets('refunded booking says sent to your bank', (t) async {
    final env = TestEnv();
    env.bookings.history = [
      makeBooking(
        status: 'cancelled',
        cancelReason: 'x',
        refund: const RefundOut(amount: 1600, status: 'refunded'),
      ),
    ];
    await pumpScreen(t, env, const BookingDetailScreen(bookingId: 1042));
    expect(find.text('Sent to your bank'), findsOneWidget);
  });

  testWidgets('delete account shows the backend message when blocked', (
    t,
  ) async {
    final env = TestEnv();
    env.profile.deleteError = const ApiException(
      kind: ApiErrorKind.conflict,
      status: 409,
      message: 'You have an upcoming booking. Please call support first.',
    );
    await pumpScreen(t, env, const DeleteAccountScreen());
    await t.tap(find.widgetWithText(CnButton, 'Send code'));
    await t.pumpAndSettle();
    expect(env.profile.deleteOtpSent, isTrue);
    await t.enterText(find.byType(TextField), '123456');
    await t.tap(find.widgetWithText(CnButton, 'Delete my account'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Delete account'));
    await t.pumpAndSettle();
    expect(
      find.text('You have an upcoming booking. Please call support first.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'bookings tabs list current and history with human status labels',
    (t) async {
      final env = TestEnv();
      env.bookings.current = [
        makeBooking(id: 1, status: 'in_progress', nurseName: 'Rahul K.'),
      ];
      env.bookings.history = [makeBooking(id: 2, status: 'completed')];
      await pumpApp(t, env);
      await t.tap(find.text('Bookings').last);
      await t.pumpAndSettle();
      expect(find.text('In progress'), findsOneWidget);
      await t.tap(find.text('History'));
      await t.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('in_progress'), findsNothing);
    },
  );

  testWidgets('empty current bookings has a way forward', (t) async {
    final env = TestEnv();
    await pumpApp(t, env);
    await t.tap(find.text('Bookings').last);
    await t.pumpAndSettle();
    expect(find.text('No current bookings'), findsOneWidget);
    expect(find.widgetWithText(CnButton, 'Book a service'), findsOneWidget);
  });
}
