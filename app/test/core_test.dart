import 'package:carenest/core/format.dart';
import 'package:carenest/core/ist.dart';
import 'package:carenest/core/money.dart';
import 'package:carenest/core/phone.dart';
import 'package:carenest/features/booking/duration_screen.dart';
import 'package:carenest/l10n/gen/app_localizations_en.dart';
import 'package:carenest/ui/status.dart';
import 'package:carenest/ui/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IST helpers', () {
    test('nowIst shifts a UTC instant by 5:30', () {
      expect(
        nowIst(() => DateTime.utc(2026, 10, 28, 4, 30)),
        DateTime(2026, 10, 28, 10),
      );
      expect(
        nowIst(() => DateTime.utc(2026, 10, 28, 20, 0)),
        DateTime(2026, 10, 29, 1, 30),
      );
    });

    test('isoSlot has no zone suffix and uses the hour', () {
      expect(isoSlot(DateTime(2026, 10, 28), 15), '2026-10-28T15:00:00');
      expect(isoSlot(DateTime(2026, 1, 5), 8), '2026-01-05T08:00:00');
    });

    test('parseWallClock ignores zone suffixes', () {
      expect(parseWallClock('2026-10-28T15:00:00'), DateTime(2026, 10, 28, 15));
      expect(
        parseWallClock('2026-10-28T15:00:00+05:30'),
        DateTime(2026, 10, 28, 15),
      );
      expect(
        parseWallClock('2026-10-28T15:00:00Z'),
        DateTime(2026, 10, 28, 15),
      );
    });

    test('parseInstant treats a bare timestamp as UTC', () {
      expect(
        parseInstant('2026-10-28T10:00:00'),
        DateTime.utc(2026, 10, 28, 10),
      );
      expect(
        parseInstant('2026-10-28T15:30:00+05:30'),
        DateTime.utc(2026, 10, 28, 10),
      );
    });

    test('isTooSoon uses the notice period', () {
      final now = DateTime(2026, 10, 28, 10);
      bool soon(int h) => isTooSoon(
        day: DateTime(2026, 10, 28),
        hour: h,
        nowWall: now,
        minNoticeMinutes: 180,
      );
      expect(soon(12), isTrue);
      expect(soon(13), isFalse);
      expect(
        isTooSoon(
          day: DateTime(2026, 10, 29),
          hour: 8,
          nowWall: now,
          minNoticeMinutes: 180,
        ),
        isFalse,
      );
    });
  });

  group('phone', () {
    test('accepts common Indian mobile formats', () {
      expect(toE164('98765 43210'), '+919876543210');
      expect(toE164('+91 98765-43210'), '+919876543210');
      expect(toE164('09876543210'), '+919876543210');
    });
    test('rejects bad numbers', () {
      expect(toE164('12345'), isNull);
      expect(toE164('5876543210'), isNull);
      expect(toE164('98765432101'), isNull);
      expect(toE164('abcdefghij'), isNull);
    });
    test(
      'masks for display',
      () => expect(maskPhone('+919876543210'), '98xxxxxx10'),
    );
  });

  test('rupees groups the Indian way', () {
    expect(rupees(400), 'Rs 400');
    expect(rupees(1600), 'Rs 1,600');
    expect(rupees(125000), 'Rs 1,25,000');
  });

  test('hour labels', () {
    expect(hourLabel(0), '12:00 AM');
    expect(hourLabel(9), '9:00 AM');
    expect(hourLabel(12), '12:00 PM');
    expect(hourLabel(15), '3:00 PM');
  });

  group('duration rules', () {
    test('offers 1 to 12 hours only', () {
      expect(offeredHours(99), List.generate(12, (i) => i + 1));
      expect(offeredHours(12).length, 12);
    });
    test('is capped by what a nurse can cover', () {
      expect(offeredHours(4), [1, 2, 3, 4]);
      expect(offeredHours(1), [1]);
    });
    test(
      'nothing offered when the cap is zero',
      () => expect(offeredHours(0), isEmpty),
    );
  });

  group('status labels', () {
    final l = AppLocalizationsEn();
    test('are human, never raw enums', () {
      expect(bookingStatusLabel(l, 'confirmed'), 'Confirmed');
      expect(bookingStatusLabel(l, 'in_progress'), 'In progress');
      expect(bookingStatusLabel(l, 'completed'), 'Completed');
      expect(bookingStatusLabel(l, 'cancelled'), 'Cancelled');
      expect(bookingStatusLabel(l, 'pending_payment'), 'Waiting for payment');
      expect(bookingStatusLabel(l, 'expired'), 'Expired');
    });
    test('unknown values fall back to plain words', () {
      expect(bookingStatusLabel(l, 'some_new_state'), 'some new state');
    });
    test('tones', () {
      expect(bookingStatusTone('cancelled'), Tone.danger);
      expect(bookingStatusTone('completed'), Tone.success);
    });
    test('refund labels', () {
      expect(refundStatusLabel(l, 'refunded'), 'Sent to your bank');
      expect(refundStatusLabel(l, 'refund_pending'), 'Refund in progress');
    });
  });
}
