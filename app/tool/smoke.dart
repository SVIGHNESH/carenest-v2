// Exercises the repositories against a running backend.
//   dart run tool/smoke.dart [baseUrl] [uvicornLog]
// Needs the backend in dev mode: OTP codes are read from its log.
import 'dart:io';
import 'dart:math';

import 'package:carenest/core/ist.dart';
import 'package:carenest/data/api/api_client.dart';
import 'package:carenest/data/api/token_store.dart';
import 'package:carenest/data/repositories/repositories.dart';

Future<String> otpFor(String phone, String logPath) async {
  for (var i = 0; i < 10; i++) {
    final lines = await File(logPath).readAsLines();
    for (final l in lines.reversed) {
      if (l.contains('DEV SMS OTP to $phone')) {
        return RegExp(r': (\d{6}) ').firstMatch(l)!.group(1)!;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  throw StateError('No OTP for $phone in $logPath');
}

Future<void> main(List<String> args) async {
  final base = args.isNotEmpty ? args[0] : 'http://localhost:8000';
  final logPath = args.length > 1 ? args[1] : '/tmp/uvicorn.log';
  final tokens = MemoryTokenStore();
  final api = ApiClient(baseUrl: base, tokens: tokens);
  final auth = HttpAuthRepository(api);
  final catalog = HttpCatalogRepository(api);
  final bookings = HttpBookingRepository(api);
  final payments = HttpPaymentRepository(api);
  final profile = HttpProfileRepository(api);

  final rnd = Random();
  final phone = '+919${(100000000 + rnd.nextInt(899999999)).toString()}';
  stdout.writeln('phone $phone');
  await auth.sendOtp(phone);
  final code = await otpFor(phone, logPath);
  final v = await auth.verifyOtp(phone, code);
  stdout.writeln('verify: needsSignup=${v.needsSignup}');
  if (v.needsSignup) {
    final u = await auth.completeSignup(
      ticket: v.signupTicket!,
      name: 'Smoke Tester',
    );
    stdout.writeln('signed up as ${u.name} ${u.phone}');
  }
  final me = await auth.restoreSession();
  stdout.writeln('session user: ${me?.name}');

  final settings = await catalog.bookingSettings();
  stdout.writeln(
    'settings: notice=${settings.minNoticeMinutes}min window=${settings.bookingWindowDays}d paused=${settings.bookingsPaused} support=${settings.supportPhone}',
  );
  final services = await catalog.services();
  stdout.writeln(
    'services: ${services.map((s) => '${s.name} Rs${s.basePrice}${s.available ? '' : ' (unavailable)'}').join(', ')}',
  );
  final service = services.firstWhere((s) => s.available);

  final now = nowIst(systemClock);
  var day = addDays(dateOnly(now), 2);
  final grid = await bookings.timeGrid(service.id, day);
  stdout.writeln(
    'time grid ${grid.date}: ${grid.slots.map((s) => '${s.hour}${s.selectable ? '' : 'x'}').join(' ')}',
  );
  final slot = grid.slots.firstWhere((s) => s.selectable);
  final max = await bookings.maxDuration(service.id, day, slot.hour);
  stdout.writeln('max duration from ${slot.hour}:00 = $max h');
  final hours = max.clamp(1, 2);
  final gender = await bookings.genderAvailability(
    service.id,
    day,
    slot.hour,
    hours,
  );
  stdout.writeln(
    'gender availability: male=${gender.male} female=${gender.female}',
  );
  final quote = await bookings.quote(service.id, hours);
  stdout.writeln(
    'quote: ${quote.basePrice} x ${quote.hours} = ${quote.amount}',
  );

  final addr = await profile.addAddress(
    const AddressInput(
      label: 'Home',
      house: '12',
      areaLine: 'Sector 14',
      city: 'Bareilly',
      state: 'Uttar Pradesh',
      pincode: '243001',
      latitude: 28.367,
      longitude: 79.4304,
    ),
  );
  stdout.writeln('address created id=${addr.id}');
  final b = await bookings.create(
    BookingRequest(
      serviceId: service.id,
      day: day,
      hour: slot.hour,
      hours: hours,
      nurseGender: gender.female ? 'female' : 'male',
      addressId: addr.id,
      patientName: 'Smoke Patient',
      contactPhone: phone,
      patientAge: 70,
      patientSex: 'female',
    ),
  );
  stdout.writeln(
    'booking created #${b.id} status=${b.status} slot=${b.slotStart} amount=${b.amount} hold until ${b.holdExpiresAt}',
  );
  final order = await payments.createOrder(b.id);
  stdout.writeln('order ${order.orderId} gateway=${order.gateway}');
  final fake = await payments.fakePay(b.id, order.orderId);
  final paid = await payments.verify(
    bookingId: b.id,
    orderId: order.orderId,
    paymentId: fake.paymentId,
    signature: fake.signature,
  );
  stdout.writeln(
    'verified: status=${paid.status} nurse=${paid.nurseName} payment=${paid.paymentStatus}',
  );
  final fetched = await bookings.get(b.id);
  stdout.writeln(
    'fetched: #${fetched.id} ${fetched.status} nurse=${fetched.nurseName} support=${fetched.supportPhone}',
  );
  final current = await bookings.mine(current: true);
  stdout.writeln('current bookings: ${current.length}');

  // Booking the same slot again with the same gender should still work or give a clean 409.
  try {
    await bookings.create(
      BookingRequest(
        serviceId: service.id,
        day: addDays(dateOnly(now), 0),
        hour: now.hour,
        hours: 1,
        nurseGender: 'female',
        addressId: addr.id,
        patientName: 'Too soon',
        contactPhone: phone,
      ),
    );
  } catch (e) {
    stdout.writeln('too-soon booking rejected as expected: $e');
  }
  exit(0);
}
