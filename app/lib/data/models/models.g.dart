// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserOut _$UserOutFromJson(Map<String, dynamic> json) => UserOut(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
);

Map<String, dynamic> _$UserOutToJson(UserOut instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'phone': instance.phone,
  'email': instance.email,
};

TokenOut _$TokenOutFromJson(Map<String, dynamic> json) => TokenOut(
  accessToken: json['access_token'] as String,
  user: UserOut.fromJson(json['user'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TokenOutToJson(TokenOut instance) => <String, dynamic>{
  'access_token': instance.accessToken,
  'user': instance.user,
};

VerifyOtpOut _$VerifyOtpOutFromJson(Map<String, dynamic> json) => VerifyOtpOut(
  needsSignup: json['needs_signup'] as bool,
  signupTicket: json['signup_ticket'] as String?,
  token: json['token'] == null
      ? null
      : TokenOut.fromJson(json['token'] as Map<String, dynamic>),
);

Map<String, dynamic> _$VerifyOtpOutToJson(VerifyOtpOut instance) =>
    <String, dynamic>{
      'needs_signup': instance.needsSignup,
      'signup_ticket': instance.signupTicket,
      'token': instance.token,
    };

ServiceOut _$ServiceOutFromJson(Map<String, dynamic> json) => ServiceOut(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  description: json['description'] as String,
  basePrice: (json['base_price'] as num).toInt(),
  active: json['active'] as bool? ?? true,
  available: json['available'] as bool? ?? true,
);

Map<String, dynamic> _$ServiceOutToJson(ServiceOut instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'base_price': instance.basePrice,
      'active': instance.active,
      'available': instance.available,
    };

BookingSettings _$BookingSettingsFromJson(Map<String, dynamic> json) =>
    BookingSettings(
      minNoticeMinutes: (json['min_notice_minutes'] as num).toInt(),
      bookingWindowDays: (json['booking_window_days'] as num).toInt(),
      bookingsPaused: json['bookings_paused'] as bool,
      supportPhone: json['support_phone'] as String,
    );

Map<String, dynamic> _$BookingSettingsToJson(BookingSettings instance) =>
    <String, dynamic>{
      'min_notice_minutes': instance.minNoticeMinutes,
      'booking_window_days': instance.bookingWindowDays,
      'bookings_paused': instance.bookingsPaused,
      'support_phone': instance.supportPhone,
    };

TimeSlot _$TimeSlotFromJson(Map<String, dynamic> json) => TimeSlot(
  hour: (json['hour'] as num).toInt(),
  free: json['free'] as bool,
  tooSoon: json['too_soon'] as bool,
);

Map<String, dynamic> _$TimeSlotToJson(TimeSlot instance) => <String, dynamic>{
  'hour': instance.hour,
  'free': instance.free,
  'too_soon': instance.tooSoon,
};

TimeGrid _$TimeGridFromJson(Map<String, dynamic> json) => TimeGrid(
  date: json['date'] as String,
  slots: (json['slots'] as List<dynamic>)
      .map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$TimeGridToJson(TimeGrid instance) => <String, dynamic>{
  'date': instance.date,
  'slots': instance.slots,
};

GenderAvailability _$GenderAvailabilityFromJson(Map<String, dynamic> json) =>
    GenderAvailability(
      male: json['male'] as bool,
      female: json['female'] as bool,
    );

Map<String, dynamic> _$GenderAvailabilityToJson(GenderAvailability instance) =>
    <String, dynamic>{'male': instance.male, 'female': instance.female};

Quote _$QuoteFromJson(Map<String, dynamic> json) => Quote(
  serviceId: (json['service_id'] as num).toInt(),
  hours: (json['hours'] as num).toInt(),
  basePrice: (json['base_price'] as num).toInt(),
  amount: (json['amount'] as num).toInt(),
);

Map<String, dynamic> _$QuoteToJson(Quote instance) => <String, dynamic>{
  'service_id': instance.serviceId,
  'hours': instance.hours,
  'base_price': instance.basePrice,
  'amount': instance.amount,
};

FamilyMember _$FamilyMemberFromJson(Map<String, dynamic> json) => FamilyMember(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  age: (json['age'] as num).toInt(),
  sex: json['sex'] as String,
  relation: json['relation'] as String,
  contactPhone: json['contact_phone'] as String?,
  medicalNotes: json['medical_notes'] as String?,
);

Map<String, dynamic> _$FamilyMemberToJson(FamilyMember instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'age': instance.age,
      'sex': instance.sex,
      'relation': instance.relation,
      'contact_phone': instance.contactPhone,
      'medical_notes': instance.medicalNotes,
    };

Address _$AddressFromJson(Map<String, dynamic> json) => Address(
  id: (json['id'] as num).toInt(),
  label: json['label'] as String,
  house: json['house'] as String,
  areaLine: json['area_line'] as String,
  city: json['city'] as String,
  state: json['state'] as String,
  pincode: json['pincode'] as String,
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  isDefault: json['is_default'] as bool,
  landmark: json['landmark'] as String?,
);

Map<String, dynamic> _$AddressToJson(Address instance) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'house': instance.house,
  'area_line': instance.areaLine,
  'city': instance.city,
  'state': instance.state,
  'pincode': instance.pincode,
  'landmark': instance.landmark,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'is_default': instance.isDefault,
};

RefundOut _$RefundOutFromJson(Map<String, dynamic> json) => RefundOut(
  amount: (json['amount'] as num).toInt(),
  status: json['status'] as String,
  expected: json['expected'] as String?,
);

Map<String, dynamic> _$RefundOutToJson(RefundOut instance) => <String, dynamic>{
  'amount': instance.amount,
  'status': instance.status,
  'expected': instance.expected,
};

Booking _$BookingFromJson(Map<String, dynamic> json) => Booking(
  id: (json['id'] as num).toInt(),
  status: json['status'] as String,
  serviceId: (json['service_id'] as num).toInt(),
  serviceName: json['service_name'] as String,
  slotStart: const WallClockConverter().fromJson(json['slot_start'] as String),
  slotEnd: const WallClockConverter().fromJson(json['slot_end'] as String),
  hours: (json['hours'] as num).toInt(),
  amount: (json['amount'] as num).toInt(),
  nurseGenderPreference: json['nurse_gender_preference'] as String,
  patientName: json['patient_name'] as String,
  contactPhone: json['contact_phone'] as String,
  addressText: json['address_text'] as String,
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  supportPhone: json['support_phone'] as String,
  nurseName: json['nurse_name'] as String?,
  patientAge: (json['patient_age'] as num?)?.toInt(),
  patientSex: json['patient_sex'] as String?,
  addressLandmark: json['address_landmark'] as String?,
  mapsUrl: json['maps_url'] as String? ?? '',
  holdExpiresAt: const InstantConverter().fromJson(
    json['hold_expires_at'] as String?,
  ),
  cancelReason: json['cancel_reason'] as String?,
  cancelledBy: json['cancelled_by'] as String?,
  paymentStatus: json['payment_status'] as String?,
  refund: json['refund'] == null
      ? null
      : RefundOut.fromJson(json['refund'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BookingToJson(Booking instance) => <String, dynamic>{
  'id': instance.id,
  'status': instance.status,
  'service_id': instance.serviceId,
  'service_name': instance.serviceName,
  'slot_start': const WallClockConverter().toJson(instance.slotStart),
  'slot_end': const WallClockConverter().toJson(instance.slotEnd),
  'hours': instance.hours,
  'amount': instance.amount,
  'nurse_gender_preference': instance.nurseGenderPreference,
  'nurse_name': instance.nurseName,
  'patient_name': instance.patientName,
  'patient_age': instance.patientAge,
  'patient_sex': instance.patientSex,
  'contact_phone': instance.contactPhone,
  'address_text': instance.addressText,
  'address_landmark': instance.addressLandmark,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'maps_url': instance.mapsUrl,
  'hold_expires_at': const InstantConverter().toJson(instance.holdExpiresAt),
  'cancel_reason': instance.cancelReason,
  'cancelled_by': instance.cancelledBy,
  'payment_status': instance.paymentStatus,
  'refund': instance.refund,
  'support_phone': instance.supportPhone,
};

OrderOut _$OrderOutFromJson(Map<String, dynamic> json) => OrderOut(
  gateway: json['gateway'] as String,
  orderId: json['order_id'] as String,
  amount: (json['amount'] as num).toInt(),
  keyId: json['key_id'] as String,
  bookingId: (json['booking_id'] as num).toInt(),
  holdExpiresAt: const InstantConverter().fromJson(
    json['hold_expires_at'] as String?,
  ),
);

Map<String, dynamic> _$OrderOutToJson(OrderOut instance) => <String, dynamic>{
  'gateway': instance.gateway,
  'order_id': instance.orderId,
  'amount': instance.amount,
  'key_id': instance.keyId,
  'booking_id': instance.bookingId,
  'hold_expires_at': const InstantConverter().toJson(instance.holdExpiresAt),
};

FakePayOut _$FakePayOutFromJson(Map<String, dynamic> json) => FakePayOut(
  paymentId: json['payment_id'] as String,
  signature: json['signature'] as String,
);

Map<String, dynamic> _$FakePayOutToJson(FakePayOut instance) =>
    <String, dynamic>{
      'payment_id': instance.paymentId,
      'signature': instance.signature,
    };
