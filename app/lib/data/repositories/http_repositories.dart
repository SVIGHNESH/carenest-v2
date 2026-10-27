import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/token_store.dart';
import '../models/models.dart';
import 'repositories.dart';

List<T> _list<T>(dynamic json, T Function(Map<String, dynamic>) f) =>
    (json as List).map((e) => f(e as Map<String, dynamic>)).toList();

Map<String, dynamic> _map(dynamic json) => json as Map<String, dynamic>;

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._api, this._tokens);
  final ApiClient _api;
  final TokenStore _tokens;

  @override
  Future<void> sendOtp(String phoneE164) =>
      _api.send('POST', '/auth/phone/send-otp', body: {'phone': phoneE164}, authenticated: false);

  @override
  Future<VerifyOtpOut> verifyOtp(String phoneE164, String code) async {
    final out = await _api.request(
      'POST',
      '/auth/phone/verify-otp',
      body: {'phone': phoneE164, 'code': code},
      authenticated: false,
      parse: (j) => VerifyOtpOut.fromJson(_map(j)),
    );
    if (out.token != null) await _tokens.write(out.token!.accessToken);
    return out;
  }

  @override
  Future<UserOut> completeSignup({required String ticket, required String name, String? email}) async {
    final out = await _api.request(
      'POST',
      '/auth/phone/complete-signup',
      body: {
        'signup_ticket': ticket,
        'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
      },
      authenticated: false,
      parse: (j) => TokenOut.fromJson(_map(j)),
    );
    await _tokens.write(out.accessToken);
    return out.user;
  }

  @override
  Future<UserOut?> restoreSession() async {
    if (await _tokens.read() == null) return null;
    try {
      return await _api.request('GET', '/users/me', authenticated: false, parse: (j) => UserOut.fromJson(_map(j)));
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.unauthorized) {
        await _tokens.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _api.send('POST', '/auth/logout', authenticated: false);
    } on ApiException {
      // The local session is cleared regardless.
    }
    await _tokens.clear();
  }
}

class HttpCatalogRepository implements CatalogRepository {
  HttpCatalogRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<ServiceOut>> services() =>
      _api.request('GET', '/services', parse: (j) => _list(j, ServiceOut.fromJson));

  @override
  Future<ServiceOut> service(int id) =>
      _api.request('GET', '/services/$id', parse: (j) => ServiceOut.fromJson(_map(j)));

  @override
  Future<BookingSettings> bookingSettings() =>
      _api.request('GET', '/settings/booking', parse: (j) => BookingSettings.fromJson(_map(j)));
}

class HttpBookingRepository implements BookingRepository {
  HttpBookingRepository(this._api);
  final ApiClient _api;

  @override
  Future<TimeGrid> timeGrid(int serviceId, String isoDate) => _api.request(
        'GET',
        '/bookings/time-grid',
        query: {'service_id': serviceId, 'date': isoDate},
        parse: (j) => TimeGrid.fromJson(_map(j)),
      );

  @override
  Future<int> maxDuration(int serviceId, String slotStart) => _api.request(
        'GET',
        '/bookings/max-duration',
        query: {'service_id': serviceId, 'start': slotStart},
        parse: (j) => _map(j)['max_hours'] as int,
      );

  @override
  Future<GenderAvailability> genderAvailability(int serviceId, String slotStart, int hours) => _api.request(
        'GET',
        '/bookings/gender-availability',
        query: {'service_id': serviceId, 'start': slotStart, 'hours': hours},
        parse: (j) => GenderAvailability.fromJson(_map(j)),
      );

  @override
  Future<Quote> quote(int serviceId, int hours) => _api.request(
        'POST',
        '/bookings/quote',
        body: {'service_id': serviceId, 'hours': hours},
        parse: (j) => Quote.fromJson(_map(j)),
      );

  @override
  Future<Booking> create(BookingRequest request) =>
      _api.request('POST', '/bookings', body: request.toJson(), parse: (j) => Booking.fromJson(_map(j)));

  @override
  Future<List<Booking>> list({required bool current}) => _api.request(
        'GET',
        '/bookings',
        query: {'view': current ? 'current' : 'history'},
        parse: (j) => _list(j, Booking.fromJson),
      );

  @override
  Future<Booking> get(int id) => _api.request('GET', '/bookings/$id', parse: (j) => Booking.fromJson(_map(j)));
}

class HttpPaymentRepository implements PaymentRepository {
  HttpPaymentRepository(this._api);
  final ApiClient _api;

  @override
  Future<OrderOut> createOrder(int bookingId) => _api.request(
        'POST',
        '/payments/create-order',
        body: {'booking_id': bookingId},
        parse: (j) => OrderOut.fromJson(_map(j)),
      );

  @override
  Future<FakePayOut> fakePay(int bookingId, String orderId) => _api.request(
        'POST',
        '/payments/fake/pay',
        body: {'booking_id': bookingId, 'order_id': orderId},
        parse: (j) => FakePayOut.fromJson(_map(j)),
      );

  @override
  Future<Booking> verify({
    required int bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) =>
      _api.request(
        'POST',
        '/payments/verify',
        body: {'booking_id': bookingId, 'order_id': orderId, 'payment_id': paymentId, 'signature': signature},
        parse: (j) => Booking.fromJson(_map(j)),
      );
}

class HttpProfileRepository implements ProfileRepository {
  HttpProfileRepository(this._api);
  final ApiClient _api;

  @override
  Future<UserOut> me() => _api.request('GET', '/users/me', parse: (j) => UserOut.fromJson(_map(j)));

  @override
  Future<UserOut> updateMe({String? name, String? email}) => _api.request(
        'PATCH',
        '/users/me',
        body: {if (name != null) 'name': name, if (email != null) 'email': email},
        parse: (j) => UserOut.fromJson(_map(j)),
      );

  @override
  Future<void> sendDeleteOtp() => _api.send('POST', '/users/me/delete-otp');

  @override
  Future<void> deleteAccount(String code) => _api.send('DELETE', '/users/me', body: {'code': code});

  @override
  Future<List<FamilyMember>> family() =>
      _api.request('GET', '/family', parse: (j) => _list(j, FamilyMember.fromJson));

  @override
  Future<FamilyMember> addFamily(FamilyInput input) =>
      _api.request('POST', '/family', body: input.toJson(), parse: (j) => FamilyMember.fromJson(_map(j)));

  @override
  Future<FamilyMember> updateFamily(int id, FamilyInput input) =>
      _api.request('PATCH', '/family/$id', body: input.toJson(), parse: (j) => FamilyMember.fromJson(_map(j)));

  @override
  Future<void> deleteFamily(int id) => _api.send('DELETE', '/family/$id');

  @override
  Future<List<Address>> addresses() =>
      _api.request('GET', '/addresses', parse: (j) => _list(j, Address.fromJson));

  @override
  Future<Address> addAddress(AddressInput input) =>
      _api.request('POST', '/addresses', body: input.toJson(), parse: (j) => Address.fromJson(_map(j)));

  @override
  Future<Address> updateAddress(int id, AddressInput input) =>
      _api.request('PATCH', '/addresses/$id', body: input.toJson(), parse: (j) => Address.fromJson(_map(j)));

  @override
  Future<void> deleteAddress(int id) => _api.send('DELETE', '/addresses/$id');

  @override
  Future<Address> setDefaultAddress(int id) => _api.request(
        'PATCH',
        '/addresses/$id',
        body: {'is_default': true},
        parse: (j) => Address.fromJson(_map(j)),
      );
}
