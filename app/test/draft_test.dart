import 'package:carenest/data/models/models.dart';
import 'package:carenest/state/booking_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

void main() {
  late ProviderContainer container;
  late TestEnv env;
  setUp(() {
    env = TestEnv();
    container = ProviderContainer(overrides: env.overrides);
    addTearDown(container.dispose);
  });

  BookingDraftController ctl() => container.read(bookingDraftProvider.notifier);
  BookingDraft draft() => container.read(bookingDraftProvider);

  test('start always begins a fresh draft', () {
    ctl().start(testServices.first);
    ctl().setSlot(DateTime(2026, 10, 29), 15);
    ctl().setHours(4);
    ctl().start(testServices.first);
    expect(draft().hours, isNull);
    expect(draft().hasSlot, isFalse);
  });

  test(
    'changing the slot clears duration and gender, same slot keeps them',
    () {
      ctl().start(testServices.first);
      ctl().setSlot(DateTime(2026, 10, 29), 15);
      ctl().setHours(4);
      ctl().setGender('female');
      ctl().setSlot(DateTime(2026, 10, 29), 15);
      expect(draft().hours, 4);
      expect(draft().gender, 'female');
      ctl().setSlot(DateTime(2026, 10, 29), 16);
      expect(draft().hours, isNull);
      expect(draft().gender, isNull);
    },
  );

  test('changing the hours clears the gender', () {
    ctl().start(testServices.first);
    ctl().setSlot(DateTime(2026, 10, 29), 15);
    ctl().setHours(4);
    ctl().setGender('male');
    ctl().setHours(5);
    expect(draft().gender, isNull);
  });

  test('member phone is used, falling back to the user phone', () {
    ctl().start(testServices.first);
    ctl().setPatientMember(testMember, fallbackPhone: '+919876543210');
    expect(draft().contactPhone, '+919811111111');
    expect(draft().patientAge, 68);
    ctl().setPatientMember(
      const FamilyMember(
        id: 6,
        name: 'S. Sharma',
        age: 64,
        sex: 'female',
        relation: 'Mother',
      ),
      fallbackPhone: '+919876543210',
    );
    expect(draft().contactPhone, '+919876543210');
  });

  test('reset clears everything', () {
    ctl().start(testServices.first);
    ctl().setSlot(DateTime(2026, 10, 29), 15);
    ctl().reset();
    expect(draft().service, isNull);
    expect(draft().hasSlot, isFalse);
  });

  test('flow notice codes map', () {
    expect(flowNoticeForCode('no_nurse_free'), FlowNotice.noNurseFree);
    expect(flowNoticeForCode('hold_expired'), FlowNotice.holdExpired);
    expect(flowNoticeForCode('crosses_midnight'), FlowNotice.crossesMidnight);
    expect(flowNoticeForCode('bad_slot'), isNull);
  });
}
