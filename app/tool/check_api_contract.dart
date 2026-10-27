// Freshness check: compares docs/openapi.json with what the hand-written
// client covers. Fails when the backend adds, removes or renames an endpoint
// or a field of a schema the app uses.
//   dart run tool/check_api_contract.dart [path/to/openapi.json]
import 'dart:convert';
import 'dart:io';

/// "METHOD /path" for every non-admin operation the app calls.
const operations = {
  'GET /addresses',
  'POST /addresses',
  'PATCH /addresses/{address_id}',
  'DELETE /addresses/{address_id}',
  'POST /auth/logout',
  'POST /auth/phone/complete-signup',
  'POST /auth/phone/send-otp',
  'POST /auth/phone/verify-otp',
  'GET /bookings',
  'POST /bookings',
  'GET /bookings/{booking_id}',
  'GET /bookings/gender-availability',
  'GET /bookings/max-duration',
  'POST /bookings/quote',
  'GET /bookings/time-grid',
  'GET /family',
  'POST /family',
  'PATCH /family/{member_id}',
  'DELETE /family/{member_id}',
  'POST /payments/create-order',
  'POST /payments/fake/pay',
  'POST /payments/verify',
  'GET /services', 'GET /services/{service_id}', 'GET /settings/booking',
  'GET /users/me',
  'PATCH /users/me',
  'DELETE /users/me',
  'POST /users/me/delete-otp',
  // Server-to-server or ops endpoints the app never calls.
  'GET /health', 'POST /payments/webhook/razorpay',
};

/// Schema name -> JSON keys the app reads or writes.
const schemas = {
  'AddressIn': [
    'area_line',
    'city',
    'house',
    'is_default',
    'label',
    'landmark',
    'latitude',
    'longitude',
    'pincode',
    'state',
  ],
  'AddressOut': [
    'area_line',
    'city',
    'house',
    'id',
    'is_default',
    'label',
    'landmark',
    'latitude',
    'longitude',
    'pincode',
    'state',
  ],
  'BookingCreateIn': [
    'address_id',
    'contact_phone',
    'hours',
    'member_id',
    'nurse_gender',
    'patient_age',
    'patient_condition',
    'patient_name',
    'patient_sex',
    'service_id',
    'slot_start',
  ],
  'BookingOut': [
    'address_landmark',
    'address_text',
    'amount',
    'cancel_reason',
    'cancelled_by',
    'contact_phone',
    'created_at',
    'hold_expires_at',
    'hours',
    'id',
    'latitude',
    'longitude',
    'maps_url',
    'nurse_gender_preference',
    'nurse_name',
    'patient_age',
    'patient_name',
    'patient_sex',
    'payment_status',
    'refund',
    'service_id',
    'service_name',
    'slot_end',
    'slot_start',
    'status',
    'support_phone',
  ],
  'BookingSettingsOut': [
    'booking_window_days',
    'bookings_paused',
    'min_notice_minutes',
    'support_phone',
  ],
  'CompleteSignupIn': ['email', 'name', 'signup_ticket'],
  'FamilyIn': [
    'age',
    'contact_phone',
    'medical_notes',
    'name',
    'relation',
    'sex',
  ],
  'FamilyOut': [
    'age',
    'contact_phone',
    'id',
    'medical_notes',
    'name',
    'relation',
    'sex',
  ],
  'GenderAvailabilityOut': ['female', 'male'],
  'MaxDurationOut': ['max_hours'],
  'OrderIn': ['booking_id'],
  'OrderOut': [
    'amount',
    'booking_id',
    'gateway',
    'hold_expires_at',
    'key_id',
    'order_id',
  ],
  'QuoteIn': ['hours', 'service_id'],
  'QuoteOut': ['amount', 'base_price', 'hours', 'service_id'],
  'RefundOut': ['amount', 'expected', 'status'],
  'SendOtpIn': ['phone'],
  'ServiceOut': [
    'active',
    'available',
    'base_price',
    'description',
    'id',
    'name',
  ],
  'TimeGridOut': ['date', 'slots'],
  'TimeSlotOut': ['free', 'hour', 'too_soon'],
  'UpdateProfileIn': ['email', 'name'],
  'UserOut': ['email', 'id', 'name', 'phone'],
  'VerifyIn': ['booking_id', 'order_id', 'payment_id', 'signature'],
  'VerifyOtpIn': ['code', 'phone'],
  'VerifyOtpOut': ['needs_signup', 'signup_ticket', 'token'],
  'DeleteAccountIn': ['code'],
  'FakePayIn': ['booking_id', 'order_id'],
  'FakePayOut': ['payment_id', 'signature'],
};

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : '../docs/openapi.json';
  final spec =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final problems = <String>[];

  final found = <String>{};
  (spec['paths'] as Map<String, dynamic>).forEach((p, ops) {
    if (p.startsWith('/admin')) return;
    for (final m in (ops as Map<String, dynamic>).keys) {
      found.add('${m.toUpperCase()} $p');
    }
  });
  for (final o in found.difference(operations)) {
    problems.add('new endpoint not covered by the app: $o');
  }
  for (final o in operations.difference(found)) {
    problems.add('endpoint removed from the API: $o');
  }

  final comps =
      (spec['components'] as Map<String, dynamic>)['schemas']
          as Map<String, dynamic>;
  schemas.forEach((name, keys) {
    final s = comps[name] as Map<String, dynamic>?;
    if (s == null) {
      problems.add('schema removed: $name');
      return;
    }
    final props = ((s['properties'] as Map<String, dynamic>?) ?? {}).keys
        .toSet();
    for (final k in props.difference(keys.toSet())) {
      problems.add('$name has new field "$k"');
    }
    for (final k in keys.toSet().difference(props)) {
      problems.add('$name lost field "$k"');
    }
  });

  if (problems.isEmpty) {
    stdout.writeln(
      'API contract matches the client (${operations.length} operations, ${schemas.length} schemas).',
    );
  } else {
    stderr.writeln('API contract drift:');
    for (final p in problems) {
      stderr.writeln('  - $p');
    }
    exit(1);
  }
}
