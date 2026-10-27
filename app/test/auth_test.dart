import 'package:carenest/data/api/api_exception.dart';
import 'package:carenest/features/auth/otp_screen.dart';
import 'package:carenest/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  group('phone entry', () {
    testWidgets('shows a validation message and does not send', (t) async {
      final env = TestEnv(signedIn: false);
      await pumpApp(t, env);
      expect(find.text('Welcome to CareNest'), findsOneWidget);

      await t.tap(find.widgetWithText(CnButton, 'Send code'));
      await t.pumpAndSettle();
      expect(find.text('Enter your mobile number'), findsOneWidget);

      await t.enterText(find.byType(TextFormField), '12345');
      await t.tap(find.widgetWithText(CnButton, 'Send code'));
      await t.pumpAndSettle();
      expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
      expect(env.auth.sentTo, isEmpty);
    });

    testWidgets('a valid number sends +91 form and opens the code screen', (
      t,
    ) async {
      final env = TestEnv(signedIn: false);
      await pumpApp(t, env);
      await t.enterText(find.byType(TextFormField), '98765 43210');
      await t.tap(find.widgetWithText(CnButton, 'Send code'));
      await t.pumpAndSettle();
      expect(env.auth.sentTo, ['+919876543210']);
      expect(find.text('Enter the code'), findsOneWidget);
      expect(find.text('We sent a 6-digit code to 98xxxxxx10'), findsOneWidget);
    });

    testWidgets('backend errors are shown', (t) async {
      final env = TestEnv(signedIn: false);
      env.auth.sendError = const ApiException(
        kind: ApiErrorKind.rateLimited,
        status: 429,
        message: 'Please wait a minute before requesting another code.',
      );
      await pumpApp(t, env);
      await t.enterText(find.byType(TextFormField), '9876543210');
      await t.tap(find.widgetWithText(CnButton, 'Send code'));
      await t.pumpAndSettle();
      expect(
        find.text('Please wait a minute before requesting another code.'),
        findsOneWidget,
      );
    });
  });

  group('code entry', () {
    Future<void> toOtp(WidgetTester t, TestEnv env) async {
      await pumpApp(t, env);
      await t.enterText(find.byType(TextFormField), '9876543210');
      await t.tap(find.widgetWithText(CnButton, 'Send code'));
      await t.pumpAndSettle();
    }

    testWidgets('resend is locked for 60 seconds then available', (t) async {
      final env = TestEnv(signedIn: false);
      await toOtp(t, env);
      expect(find.text('Resend code in 1:00'), findsOneWidget);
      await t.pump(const Duration(seconds: 30));
      expect(find.text('Resend code in 0:30'), findsOneWidget);
      await t.pump(const Duration(seconds: 30));
      expect(find.widgetWithText(CnButton, 'Resend code'), findsOneWidget);
      await t.tap(find.widgetWithText(CnButton, 'Resend code'));
      await t.pumpAndSettle();
      expect(env.auth.sentTo.length, 2);
      expect(find.text('Resend code in 1:00'), findsOneWidget);
    });

    testWidgets('a wrong code shows the backend message', (t) async {
      final env = TestEnv(signedIn: false);
      env.auth.verifyError = const ApiException(
        kind: ApiErrorKind.validation,
        status: 400,
        message: 'Incorrect code.',
      );
      await toOtp(t, env);
      await t.enterText(find.byType(TextField), '123456');
      await t.pumpAndSettle();
      expect(find.text('Incorrect code.'), findsOneWidget);
    });

    testWidgets('a short code is rejected locally', (t) async {
      final env = TestEnv(signedIn: false);
      await toOtp(t, env);
      await t.enterText(find.byType(TextField), '123');
      await t.tap(find.widgetWithText(CnButton, 'Verify'));
      await t.pumpAndSettle();
      expect(find.text('Enter the 6-digit code'), findsOneWidget);
      expect(otpLength, 6);
    });

    testWidgets('existing user lands on home', (t) async {
      final env = TestEnv(signedIn: false);
      await toOtp(t, env);
      await t.enterText(find.byType(TextField), '123456');
      await t.pumpAndSettle();
      expect(find.text('Hello, Riya'), findsOneWidget);
    });

    testWidgets('new user is asked for a name, email optional', (t) async {
      final env = TestEnv(signedIn: false)..auth.newUser = true;
      await toOtp(t, env);
      await t.enterText(find.byType(TextField), '123456');
      await t.pumpAndSettle();
      expect(find.text('Tell us about you'), findsWidgets);
      await t.tap(find.widgetWithText(CnButton, 'Get started'));
      await t.pumpAndSettle();
      expect(find.text('Enter a name'), findsOneWidget);
      await t.enterText(find.byType(TextFormField).first, 'Asha Verma');
      await t.tap(find.widgetWithText(CnButton, 'Get started'));
      await t.pumpAndSettle();
      expect(find.text('Hello, Asha'), findsOneWidget);
    });
  });

  testWidgets('a stored session skips login', (t) async {
    await pumpApp(t, TestEnv());
    expect(find.text('Hello, Riya'), findsOneWidget);
  });
}
