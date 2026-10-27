import '../../core/ist.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/token_store.dart';
import '../models/models.dart';

typedef Json = Map<String, dynamic>;

List<T> _list<T>(dynamic d, T Function(Json) f) =>
    (d as List).map((e) => f(e as Json)).toList(growable: false);

// ---------------------------------------------------------------- auth
abstract class AuthRepository {
  Future<String?> storedToken();

  /// Current user for the stored token, or null when there is no valid session.
  Future<UserOut?> restoreSession();
  Future<void> sendOtp(String phoneE164);

  /// Stores the token when the user already exists.
  Future<VerifyOtpOut> verifyOtp(String phoneE164, String code);
  Future<UserOut> completeSignup({
    required String ticket,
    required String name,
    String? email,
  });
  Future<void> logout();
}

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._api);
  final ApiClient _api;
  TokenStore get _tokens => _api.tokens;

  @override
  Future<String?> storedToken() => _tokens.read();

  @override
  Future<UserOut?> restoreSession() async {
    if (await _tokens.read() == null) return null;
    try {
      return await _api.get('/users/me', (d) => UserOut.fromJson(d as Json));
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.unauthorized) return null;
      rethrow;
    }
  }

  @override
  Future<void> sendOtp(String phoneE164) =>
      _api.postVoid('/auth/phone/send-otp', body: {'phone': phoneE164});

  @override
  Future<VerifyOtpOut> verifyOtp(String phoneE164, String code) async {
    final out = await _api.post(
      '/auth/phone/verify-otp',
      (d) => VerifyOtpOut.fromJson(d as Json),
      body: {'phone': phoneE164, 'code': code},
    );
    final t = out.token;
    if (t != null) await _tokens.write(t.accessToken);
    return out;
  }

  @override
  Future<UserOut> completeSignup({
    required String ticket,
    required String name,
    String? email,
  }) async {
    final t = await _api.post(
      '/auth/phone/complete-signup',
      (d) => TokenOut.fromJson(d as Json),
      body: {
        'signup_ticket': ticket,
        'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    await _tokens.write(t.accessToken);
    return t.user;
  }

  @override
  Future<void> logout() async {
    try {
      await _api.postVoid('/auth/logout');
    } finally {
      await _tokens.clear();
    }
  }
}

// ------------------------------------------------------------- profile
class AddressInput {
  const AddressInput({
    required this.label,
    required this.house,
    required this.areaLine,
    required this.city,
    required this.state,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    this.landmark,
    this.isDefault = false,
  });
  final String label, house, areaLine, city, state, pincode;
  final String? landmark;
  final double latitude, longitude;
  final bool isDefault;

  Json toJson() => {
    'label': label,
    'house': house,
    'area_line': areaLine,
    'city': city,
    'state': state,
    'pincode': pincode,
    'landmark': (landmark == null || landmark!.trim().isEmpty)
        ? null
        : landmark!.trim(),
    'latitude': latitude,
    'longitude': longitude,
    'is_default': isDefault,
  };
}

class FamilyInput {
  const FamilyInput({
    required this.name,
    required this.relation,
    required this.age,
    required this.sex,
    this.contactPhone,
    this.medicalNotes,
  });
  final String name, relation, sex;
  final int age;
  final String? contactPhone, medicalNotes;

  Json toJson() => {
    'name': name,
    'relation': relation,
    'age': age,
    'sex': sex,
    'contact_phone': contactPhone,
    'medical_notes': medicalNotes,
  };
}

abstract class ProfileRepository {
  Future<UserOut> me();
  Future<UserOut> updateMe({String? name, String? email});
  Future<void> sendDeleteOtp();
  Future<void> deleteAccount(String code);

  Future<List<FamilyMember>> family();
  Future<FamilyMember> addFamily(FamilyInput input);
  Future<FamilyMember> updateFamily(int id, FamilyInput input);
  Future<void> deleteFamily(int id);

  Future<List<Address>> addresses();
  Future<Address> addAddress(AddressInput input);
  Future<Address> updateAddress(int id, Json patch);
  Future<void> deleteAddress(int id);
}

class HttpProfileRepository implements ProfileRepository {
  HttpProfileRepository(this._api);
  final ApiClient _api;

  @override
  Future<UserOut> me() =>
      _api.get('/users/me', (d) => UserOut.fromJson(d as Json));

  @override
  Future<UserOut> updateMe({String? name, String? email}) => _api.patch(
    '/users/me',
    (d) => UserOut.fromJson(d as Json),
    body: {
      'name': ?name,
      if (email != null) 'email': email.isEmpty ? null : email,
    },
  );

  @override
  Future<void> sendDeleteOtp() => _api.postVoid('/users/me/delete-otp');

  @override
  Future<void> deleteAccount(String code) async {
    await _api.delete('/users/me', body: {'code': code});
    await _api.tokens.clear();
  }

  @override
  Future<List<FamilyMember>> family() =>
      _api.get('/family', (d) => _list(d, FamilyMember.fromJson));

  @override
  Future<FamilyMember> addFamily(FamilyInput i) => _api.post(
    '/family',
    (d) => FamilyMember.fromJson(d as Json),
    body: i.toJson(),
  );

  @override
  Future<FamilyMember> updateFamily(int id, FamilyInput i) => _api.patch(
    '/family/$id',
    (d) => FamilyMember.fromJson(d as Json),
    body: i.toJson(),
  );

  @override
  Future<void> deleteFamily(int id) => _api.delete('/family/$id');

  @override
  Future<List<Address>> addresses() =>
      _api.get('/addresses', (d) => _list(d, Address.fromJson));

  @override
  Future<Address> addAddress(AddressInput i) => _api.post(
    '/addresses',
    (d) => Address.fromJson(d as Json),
    body: i.toJson(),
  );

  @override
  Future<Address> updateAddress(int id, Json patch) => _api.patch(
    '/addresses/$id',
    (d) => Address.fromJson(d as Json),
    body: patch,
  );

  @override
  Future<void> deleteAddress(int id) => _api.delete('/addresses/$id');
}

// ------------------------------------------------------------- catalog
abstract class CatalogRepository {
  Future<List<ServiceOut>> services();
  Future<ServiceOut> service(int id);
  Future<BookingSettings> bookingSettings();
}

class HttpCatalogRepository implements CatalogRepository {
  HttpCatalogRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<ServiceOut>> services() =>
      _api.get('/services', (d) => _list(d, ServiceOut.fromJson));

  @override
  Future<ServiceOut> service(int id) =>
      _api.get('/services/$id', (d) => ServiceOut.fromJson(d as Json));

  @override
  Future<BookingSettings> bookingSettings() =>
      _api.get('/settings/booking', (d) => BookingSettings.fromJson(d as Json));
}

// ------------------------------------------------------------ bookings
class BookingRequest {
  const BookingRequest({
    required this.serviceId,
    required this.day,
    required this.hour,
    required this.hours,
    required this.nurseGender,
    required this.addressId,
    required this.patientName,
    required this.contactPhone,
    this.memberId,
    this.patientAge,
    this.patientSex,
    this.patientCondition,
  });
  final int serviceId, hour, hours, addressId;
  final DateTime day;
  final String nurseGender, patientName, contactPhone;
  final int? memberId, patientAge;
  final String? patientSex, patientCondition;

  Json toJson() => {
    'service_id': serviceId,
    'slot_start': isoSlot(day, hour),
    'hours': hours,
    'nurse_gender': nurseGender,
    'address_id': addressId,
    'member_id': memberId,
    'patient_name': patientName,
    'patient_age': patientAge,
    'patient_sex': patientSex,
    'patient_condition':
        (patientCondition == null || patientCondition!.trim().isEmpty)
        ? null
        : patientCondition,
    'contact_phone': contactPhone,
  };
}

abstract class BookingRepository {
  Future<TimeGrid> timeGrid(int serviceId, DateTime day);
  Future<int> maxDuration(int serviceId, DateTime day, int hour);
  Future<GenderAvailability> genderAvailability(
    int serviceId,
    DateTime day,
    int hour,
    int hours,
  );
  Future<Quote> quote(int serviceId, int hours);
  Future<Booking> create(BookingRequest request);
  Future<List<Booking>> mine({required bool current});
  Future<Booking> get(int id);
}

class HttpBookingRepository implements BookingRepository {
  HttpBookingRepository(this._api);
  final ApiClient _api;

  @override
  Future<TimeGrid> timeGrid(int serviceId, DateTime day) => _api.get(
    '/bookings/time-grid',
    (d) => TimeGrid.fromJson(d as Json),
    query: {'service_id': serviceId, 'date': isoDate(day)},
  );

  @override
  Future<int> maxDuration(int serviceId, DateTime day, int hour) => _api.get(
    '/bookings/max-duration',
    (d) => (d as Json)['max_hours'] as int,
    query: {'service_id': serviceId, 'start': isoSlot(day, hour)},
  );

  @override
  Future<GenderAvailability> genderAvailability(
    int serviceId,
    DateTime day,
    int hour,
    int hours,
  ) => _api.get(
    '/bookings/gender-availability',
    (d) => GenderAvailability.fromJson(d as Json),
    query: {
      'service_id': serviceId,
      'start': isoSlot(day, hour),
      'hours': hours,
    },
  );

  @override
  Future<Quote> quote(int serviceId, int hours) => _api.post(
    '/bookings/quote',
    (d) => Quote.fromJson(d as Json),
    body: {'service_id': serviceId, 'hours': hours},
  );

  @override
  Future<Booking> create(BookingRequest r) => _api.post(
    '/bookings',
    (d) => Booking.fromJson(d as Json),
    body: r.toJson(),
  );

  @override
  Future<List<Booking>> mine({required bool current}) => _api.get(
    '/bookings',
    (d) => _list(d, Booking.fromJson),
    query: {'view': current ? 'current' : 'history'},
  );

  @override
  Future<Booking> get(int id) =>
      _api.get('/bookings/$id', (d) => Booking.fromJson(d as Json));
}

// ------------------------------------------------------------ payments
abstract class PaymentRepository {
  Future<OrderOut> createOrder(int bookingId);
  Future<FakePayOut> fakePay(int bookingId, String orderId);
  Future<Booking> verify({
    required int bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  });
}

class HttpPaymentRepository implements PaymentRepository {
  HttpPaymentRepository(this._api);
  final ApiClient _api;

  @override
  Future<OrderOut> createOrder(int bookingId) => _api.post(
    '/payments/create-order',
    (d) => OrderOut.fromJson(d as Json),
    body: {'booking_id': bookingId},
  );

  @override
  Future<FakePayOut> fakePay(int bookingId, String orderId) => _api.post(
    '/payments/fake/pay',
    (d) => FakePayOut.fromJson(d as Json),
    body: {'booking_id': bookingId, 'order_id': orderId},
  );

  @override
  Future<Booking> verify({
    required int bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) => _api.post(
    '/payments/verify',
    (d) => Booking.fromJson(d as Json),
    body: {
      'booking_id': bookingId,
      'order_id': orderId,
      'payment_id': paymentId,
      'signature': signature,
    },
  );
}
