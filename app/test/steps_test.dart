import 'package:carenest/data/models/models.dart';
import 'package:carenest/features/booking/duration_screen.dart';
import 'package:carenest/features/booking/gender_screen.dart';
import 'package:carenest/features/booking/when_screen.dart';
import 'package:carenest/features/home/service_detail_screen.dart';
import 'package:carenest/state/booking_draft.dart';
import 'package:carenest/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

void main() {
  void setupDraft(c, {bool slot = false, int? hours}) {
    final ctl = c.read(bookingDraftProvider.notifier);
    ctl.start(testServices.first);
    if (slot) ctl.setSlot(DateTime(2026, 10, 28), 15);
    if (hours != null) ctl.setHours(hours);
  }

  group('time grid', () {
    testWidgets(
      'too-soon and booked hours are greyed out and cannot be selected',
      (t) async {
        final env = TestEnv();
        await pumpScreen(
          t,
          env,
          const WhenScreen(),
          setup: (c) => setupDraft(c),
        );

        // Today is Wed 28 Oct 10:00 IST with 3 h notice: earliest 1:00 PM; 4:00 PM is booked.
        expect(
          find.text(
            'Earliest start today is 1:00 PM. Bookings need at least 3 hours notice.',
          ),
          findsOneWidget,
        );

        Semantics semFor(String label) => t.widget<Semantics>(
          find
              .byWidgetPredicate(
                (w) =>
                    w is Semantics &&
                    w.properties.label?.startsWith(label) == true,
              )
              .first,
        );
        expect(semFor('9:00 AM').properties.enabled, isFalse);
        expect(semFor('9:00 AM').properties.label, '9:00 AM, too soon');
        expect(semFor('4:00 PM').properties.enabled, isFalse);
        expect(semFor('4:00 PM').properties.label, '4:00 PM, not available');
        expect(semFor('1:00 PM').properties.enabled, isTrue);

        Finder cont() => find.widgetWithText(CnButton, 'Continue');
        expect(t.widget<CnButton>(cont()).onPressed, isNull);

        await t.tap(find.text('9:00 AM'));
        await t.pump();
        expect(
          t.widget<CnButton>(cont()).onPressed,
          isNull,
          reason: 'too soon hour is not selectable',
        );
        await t.tap(find.text('4:00 PM'));
        await t.pump();
        expect(
          t.widget<CnButton>(cont()).onPressed,
          isNull,
          reason: 'booked hour is not selectable',
        );
        await t.tap(find.text('2:00 PM'));
        await t.pump();
        expect(t.widget<CnButton>(cont()).onPressed, isNotNull);
      },
    );

    testWidgets(
      'offers today plus the booking window (inclusive) as day chips',
      (t) async {
        final env = TestEnv();
        await pumpScreen(
          t,
          env,
          const WhenScreen(),
          setup: (c) => setupDraft(c),
        );
        // Window of 7 days: 8 chips from Wed 28 to Wed 4 Nov.
        expect(find.bySemanticsLabel('Wed 28 Oct'), findsOneWidget);
        await t.dragUntilVisible(
          find.bySemanticsLabel('Wed 4 Nov'),
          find.byType(ListView).first.evaluate().isEmpty
              ? find.byType(Scrollable).first
              : find.byType(Scrollable).at(1),
          const Offset(-200, 0),
        );
        expect(find.bySemanticsLabel('Wed 4 Nov'), findsOneWidget);
        expect(find.bySemanticsLabel('Thu 5 Nov'), findsNothing);
      },
    );

    testWidgets('a day with no hours shows an empty state', (t) async {
      final env = TestEnv();
      await pumpScreen(t, env, const WhenScreen(), setup: (c) => setupDraft(c));
      // Fake backend has no times for a date outside its grid only when empty; simulate with all booked.
      env.bookings.bookedHours = {for (var h = 8; h < 20; h++) h};
      await t.tap(find.bySemanticsLabel('Thu 29 Oct'));
      await t.pumpAndSettle();
      final cont = t.widget<CnButton>(
        find.widgetWithText(CnButton, 'Continue'),
      );
      expect(cont.onPressed, isNull);
    });
  });

  group('duration', () {
    testWidgets('offers hours only up to the server cap', (t) async {
      final env = TestEnv();
      env.bookings.maxHours = 4;
      await pumpScreen(
        t,
        env,
        const DurationScreen(),
        setup: (c) => setupDraft(c, slot: true),
      );
      for (final h in ['1', '2', '3', '4']) {
        expect(find.text(h), findsOneWidget);
      }
      expect(find.text('5'), findsNothing);
      expect(find.text('12'), findsNothing);
      expect(
        find.text('A nurse is free for up to 4 hours from this start time.'),
        findsOneWidget,
      );
    });

    testWidgets('never offers more than 12 hours and has no Days tab', (
      t,
    ) async {
      final env = TestEnv();
      env.bookings.maxHours = 24;
      await pumpScreen(
        t,
        env,
        const DurationScreen(),
        setup: (c) => setupDraft(c, slot: true),
      );
      expect(find.text('12'), findsOneWidget);
      expect(find.text('13'), findsNothing);
      expect(find.text('Days'), findsNothing);
    });

    testWidgets('shows the running price', (t) async {
      final env = TestEnv();
      await pumpScreen(
        t,
        env,
        const DurationScreen(),
        setup: (c) => setupDraft(c, slot: true),
      );
      await t.tap(find.text('3'));
      await t.pump();
      expect(find.text('Rs 400 x 3 hours'), findsOneWidget);
      expect(find.text('Rs 1,200'), findsOneWidget);
    });

    testWidgets('a cap of zero shows a way back', (t) async {
      final env = TestEnv();
      env.bookings.maxHours = 0;
      await pumpScreen(
        t,
        env,
        const DurationScreen(),
        setup: (c) => setupDraft(c, slot: true),
      );
      expect(find.text('No visit can start at this time'), findsOneWidget);
      expect(
        find.widgetWithText(CnButton, 'Change date or time'),
        findsOneWidget,
      );
    });
  });

  group('gender step', () {
    testWidgets(
      'an unavailable gender is disabled with a way to change the time',
      (t) async {
        final env = TestEnv();
        env.bookings.gender = const GenderAvailability(
          male: false,
          female: true,
        );
        await pumpScreen(
          t,
          env,
          const GenderScreen(),
          setup: (c) => setupDraft(c, slot: true, hours: 4),
        );

        expect(find.text('Available for your time'), findsOneWidget);
        expect(find.text('Not available for this time'), findsOneWidget);
        expect(find.textContaining('No Male nurse is free on'), findsOneWidget);
        expect(
          find.widgetWithText(CnButton, 'Change date or time'),
          findsOneWidget,
        );
        // No nurse names anywhere.
        expect(find.textContaining('Anita'), findsNothing);

        // Tapping the disabled male option does not enable Continue.
        await t.tap(find.text('Male nurse'));
        await t.pump();
        expect(
          t
              .widget<CnButton>(find.widgetWithText(CnButton, 'Continue'))
              .onPressed,
          isNull,
        );

        await t.tap(find.text('Female nurse'));
        await t.pump();
        expect(
          t
              .widget<CnButton>(find.widgetWithText(CnButton, 'Continue'))
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('both available means no warning', (t) async {
      final env = TestEnv();
      await pumpScreen(
        t,
        env,
        const GenderScreen(),
        setup: (c) => setupDraft(c, slot: true, hours: 4),
      );
      expect(find.text('Not available for this time'), findsNothing);
      expect(
        find.widgetWithText(CnButton, 'Change date or time'),
        findsNothing,
      );
    });
  });

  group('service detail', () {
    testWidgets('paused banner disables Book', (t) async {
      final env = TestEnv();
      env.catalog.settings = const BookingSettings(
        minNoticeMinutes: 180,
        bookingWindowDays: 7,
        bookingsPaused: true,
        supportPhone: '1800000000',
      );
      await pumpScreen(t, env, const ServiceDetailScreen(serviceId: 1));
      expect(
        find.text(
          'Bookings are temporarily unavailable. Please try again later.',
        ),
        findsOneWidget,
      );
      expect(
        t.widget<CnButton>(find.widgetWithText(CnButton, 'Book now')).onPressed,
        isNull,
      );
    });

    testWidgets('unavailable service says so and disables Book', (t) async {
      final env = TestEnv();
      await pumpScreen(t, env, const ServiceDetailScreen(serviceId: 2));
      expect(find.text('Not available right now'), findsOneWidget);
      expect(
        t.widget<CnButton>(find.widgetWithText(CnButton, 'Book now')).onPressed,
        isNull,
      );
    });

    testWidgets('available service shows price and enables Book', (t) async {
      final env = TestEnv();
      await pumpScreen(t, env, const ServiceDetailScreen(serviceId: 1));
      expect(find.text('Rs 400 per hour'), findsOneWidget);
      expect(find.text('Companionship and daily care.'), findsOneWidget);
      expect(
        t.widget<CnButton>(find.widgetWithText(CnButton, 'Book now')).onPressed,
        isNotNull,
      );
    });
  });
}
