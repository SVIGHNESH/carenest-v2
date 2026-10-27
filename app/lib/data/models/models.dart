import 'package:json_annotation/json_annotation.dart';

import '../../core/ist.dart';

part 'models.g.dart';

class WallClockConverter implements JsonConverter<DateTime, String> {
  const WallClockConverter();
  @override
  DateTime fromJson(String json) => parseWallClock(json);
  @override
  String toJson(DateTime object) => object.toIso8601String();
}

class InstantConverter implements JsonConverter<DateTime?, String?> {
  const InstantConverter();
  @override
  DateTime? fromJson(String? json) => json == null ? null : parseInstant(json);
  @override
  String? toJson(DateTime? object) => object?.toIso8601String();
}

@JsonSerializable()
class UserOut {
  const UserOut({required this.id, required this.name, this.phone, this.email});
  factory UserOut.fromJson(Map<String, dynamic> json) =>
      _$UserOutFromJson(json);
  final int id;
  final String name;
  final String? phone;
  final String? email;
  Map<String, dynamic> toJson() => _$UserOutToJson(this);
}

@JsonSerializable()
class TokenOut {
  const TokenOut({required this.accessToken, required this.user});
  factory TokenOut.fromJson(Map<String, dynamic> json) =>
      _$TokenOutFromJson(json);
  @JsonKey(name: 'access_token')
  final String accessToken;
  final UserOut user;
}

@JsonSerializable()
class VerifyOtpOut {
  const VerifyOtpOut({
    required this.needsSignup,
    this.signupTicket,
    this.token,
  });
  factory VerifyOtpOut.fromJson(Map<String, dynamic> json) =>
      _$VerifyOtpOutFromJson(json);
  @JsonKey(name: 'needs_signup')
  final bool needsSignup;
  @JsonKey(name: 'signup_ticket')
  final String? signupTicket;
  final TokenOut? token;
}

@JsonSerializable()
class ServiceOut {
  const ServiceOut({
    required this.id,
    required this.name,
    required this.description,
    required this.basePrice,
    this.active = true,
    this.available = true,
  });
  factory ServiceOut.fromJson(Map<String, dynamic> json) =>
      _$ServiceOutFromJson(json);
  final int id;
  final String name;
  final String description;
  @JsonKey(name: 'base_price')
  final int basePrice;
  final bool active;
  final bool available;
}

@JsonSerializable()
class BookingSettings {
  const BookingSettings({
    required this.minNoticeMinutes,
    required this.bookingWindowDays,
    required this.bookingsPaused,
    required this.supportPhone,
  });
  factory BookingSettings.fromJson(Map<String, dynamic> json) =>
      _$BookingSettingsFromJson(json);
  @JsonKey(name: 'min_notice_minutes')
  final int minNoticeMinutes;
  @JsonKey(name: 'booking_window_days')
  final int bookingWindowDays;
  @JsonKey(name: 'bookings_paused')
  final bool bookingsPaused;
  @JsonKey(name: 'support_phone')
  final String supportPhone;
}

@JsonSerializable()
class TimeSlot {
  const TimeSlot({
    required this.hour,
    required this.free,
    required this.tooSoon,
  });
  factory TimeSlot.fromJson(Map<String, dynamic> json) =>
      _$TimeSlotFromJson(json);
  final int hour;
  final bool free;
  @JsonKey(name: 'too_soon')
  final bool tooSoon;

  bool get selectable => free && !tooSoon;
}

@JsonSerializable()
class TimeGrid {
  const TimeGrid({required this.date, required this.slots});
  factory TimeGrid.fromJson(Map<String, dynamic> json) =>
      _$TimeGridFromJson(json);
  final String date;
  final List<TimeSlot> slots;
}

@JsonSerializable()
class GenderAvailability {
  const GenderAvailability({required this.male, required this.female});
  factory GenderAvailability.fromJson(Map<String, dynamic> json) =>
      _$GenderAvailabilityFromJson(json);
  final bool male;
  final bool female;
}

@JsonSerializable()
class Quote {
  const Quote({
    required this.serviceId,
    required this.hours,
    required this.basePrice,
    required this.amount,
  });
  factory Quote.fromJson(Map<String, dynamic> json) => _$QuoteFromJson(json);
  @JsonKey(name: 'service_id')
  final int serviceId;
  final int hours;
  @JsonKey(name: 'base_price')
  final int basePrice;
  final int amount;
}

@JsonSerializable()
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.age,
    required this.sex,
    required this.relation,
    this.contactPhone,
    this.medicalNotes,
  });
  factory FamilyMember.fromJson(Map<String, dynamic> json) =>
      _$FamilyMemberFromJson(json);
  final int id;
  final String name;
  final int age;
  final String sex;
  final String relation;
  @JsonKey(name: 'contact_phone')
  final String? contactPhone;
  @JsonKey(name: 'medical_notes')
  final String? medicalNotes;
}

@JsonSerializable()
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.house,
    required this.areaLine,
    required this.city,
    required this.state,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    required this.isDefault,
    this.landmark,
  });
  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);
  final int id;
  final String label;
  final String house;
  @JsonKey(name: 'area_line')
  final String areaLine;
  final String city;
  final String state;
  final String pincode;
  final String? landmark;
  final double latitude;
  final double longitude;
  @JsonKey(name: 'is_default')
  final bool isDefault;

  /// Single-line summary: house, area, city.
  String get summary => [
    house,
    areaLine,
    city,
    state,
    pincode,
  ].where((p) => p.trim().isNotEmpty).join(', ');
  String get shortSummary =>
      [areaLine, city].where((p) => p.trim().isNotEmpty).join(', ');
}

@JsonSerializable()
class RefundOut {
  const RefundOut({required this.amount, required this.status, this.expected});
  factory RefundOut.fromJson(Map<String, dynamic> json) =>
      _$RefundOutFromJson(json);
  final int amount;
  final String status;
  final String? expected;

  bool get isSent => status == 'refunded';
}

@JsonSerializable()
class Booking {
  const Booking({
    required this.id,
    required this.status,
    required this.serviceId,
    required this.serviceName,
    required this.slotStart,
    required this.slotEnd,
    required this.hours,
    required this.amount,
    required this.nurseGenderPreference,
    required this.patientName,
    required this.contactPhone,
    required this.addressText,
    required this.latitude,
    required this.longitude,
    required this.supportPhone,
    this.nurseName,
    this.patientAge,
    this.patientSex,
    this.addressLandmark,
    this.mapsUrl = '',
    this.holdExpiresAt,
    this.cancelReason,
    this.cancelledBy,
    this.paymentStatus,
    this.refund,
  });
  factory Booking.fromJson(Map<String, dynamic> json) =>
      _$BookingFromJson(json);
  final int id;
  final String status;
  @JsonKey(name: 'service_id')
  final int serviceId;
  @JsonKey(name: 'service_name')
  final String serviceName;
  @JsonKey(name: 'slot_start')
  @WallClockConverter()
  final DateTime slotStart;
  @JsonKey(name: 'slot_end')
  @WallClockConverter()
  final DateTime slotEnd;
  final int hours;
  final int amount;
  @JsonKey(name: 'nurse_gender_preference')
  final String nurseGenderPreference;
  @JsonKey(name: 'nurse_name')
  final String? nurseName;
  @JsonKey(name: 'patient_name')
  final String patientName;
  @JsonKey(name: 'patient_age')
  final int? patientAge;
  @JsonKey(name: 'patient_sex')
  final String? patientSex;
  @JsonKey(name: 'contact_phone')
  final String contactPhone;
  @JsonKey(name: 'address_text')
  final String addressText;
  @JsonKey(name: 'address_landmark')
  final String? addressLandmark;
  final double latitude;
  final double longitude;
  @JsonKey(name: 'maps_url')
  final String mapsUrl;
  @JsonKey(name: 'hold_expires_at')
  @InstantConverter()
  final DateTime? holdExpiresAt;
  @JsonKey(name: 'cancel_reason')
  final String? cancelReason;
  @JsonKey(name: 'cancelled_by')
  final String? cancelledBy;
  @JsonKey(name: 'payment_status')
  final String? paymentStatus;
  final RefundOut? refund;
  @JsonKey(name: 'support_phone')
  final String supportPhone;

  bool get isCancelled => status == 'cancelled';
  bool get isConfirmed =>
      status == 'confirmed' || status == 'in_progress' || status == 'completed';
}

@JsonSerializable()
class OrderOut {
  const OrderOut({
    required this.gateway,
    required this.orderId,
    required this.amount,
    required this.keyId,
    required this.bookingId,
    this.holdExpiresAt,
  });
  factory OrderOut.fromJson(Map<String, dynamic> json) =>
      _$OrderOutFromJson(json);
  final String gateway;
  @JsonKey(name: 'order_id')
  final String orderId;
  final int amount;
  @JsonKey(name: 'key_id')
  final String keyId;
  @JsonKey(name: 'booking_id')
  final int bookingId;
  @JsonKey(name: 'hold_expires_at')
  @InstantConverter()
  final DateTime? holdExpiresAt;
}

@JsonSerializable()
class FakePayOut {
  const FakePayOut({required this.paymentId, required this.signature});
  factory FakePayOut.fromJson(Map<String, dynamic> json) =>
      _$FakePayOutFromJson(json);
  @JsonKey(name: 'payment_id')
  final String paymentId;
  final String signature;
}
