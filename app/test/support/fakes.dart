import 'package:carenest/core/ist.dart';
import 'package:carenest/data/api/api_exception.dart';
import 'package:carenest/data/models/models.dart';
import 'package:carenest/data/repositories/repositories.dart';

/// 2026-10-28 10:00 IST, so today's hours before 13:00 are "too soon" with 3 h notice.
DateTime fixedClock() => DateTime.utc(2026, 10, 28, 4, 30);

const testUser = UserOut(
  id: 1,
  name: 'Riya Sharma',
  phone: '+919876543210',
  email: 'riya@example.com',
);

const testServices = [
  ServiceOut(
    id: 1,
    name: 'Elder care',
    description: 'Companionship and daily care.',
    basePrice: 400,
  ),
  ServiceOut(
    id: 2,
    name: 'Physiotherapy',
    description: 'Guided exercises.',
    basePrice: 600,
    available: false,
  ),
];

const testSettings = BookingSettings(
  minNoticeMinutes: 180,
  bookingWindowDays: 7,
  bookingsPaused: false,
  supportPhone: '1800000000',
);

const testAddress = Address(
  id: 10,
  label: 'Home',
  house: '221',
  areaLine: 'Sector 14',
  city: 'Bareilly',
  state: 'Uttar Pradesh',
  pincode: '243001',
  latitude: 28.367,
  longitude: 79.43,
  isDefault: true,
  landmark: 'Near City Park',
);

const testMember = FamilyMember(
  id: 5,
  name: 'R. Sharma',
  age: 68,
  sex: 'male',
  relation: 'Father',
  contactPhone: '+919811111111',
);

Booking makeBooking({
  int id = 1042,
  String status = 'pending_payment',
  DateTime? holdExpiresAt,
  String? nurseName,
  int amount = 1600,
  String? cancelReason,
  RefundOut? refund,
  String? cancelledBy,
}) => Booking(
  id: id,
  status: status,
  serviceId: 1,
  serviceName: 'Elder care',
  slotStart: DateTime(2026, 10, 29, 15),
  slotEnd: DateTime(2026, 10, 29, 19),
  hours: 4,
  amount: amount,
  nurseGenderPreference: 'female',
  patientName: 'Riya Sharma',
  contactPhone: '+919876543210',
  addressText: '221, Sector 14, Bareilly, Uttar Pradesh, 243001',
  latitude: 28.367,
  longitude: 79.43,
  supportPhone: '1800000000',
  nurseName: nurseName,
  holdExpiresAt: holdExpiresAt,
  cancelReason: cancelReason,
  cancelledBy: cancelledBy,
  refund: refund,
);

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.signedIn = true});
  bool signedIn;
  final sentTo = <String>[];
  ApiException? sendError;
  ApiException? verifyError;
  bool newUser = false;

  @override
  Future<String?> storedToken() async => signedIn ? 't' : null;

  @override
  Future<UserOut?> restoreSession() async => signedIn ? testUser : null;

  @override
  Future<void> sendOtp(String phoneE164) async {
    if (sendError != null) throw sendError!;
    sentTo.add(phoneE164);
  }

  @override
  Future<VerifyOtpOut> verifyOtp(String phoneE164, String code) async {
    if (verifyError != null) throw verifyError!;
    if (newUser) {
      return const VerifyOtpOut(needsSignup: true, signupTicket: 'ticket');
    }
    signedIn = true;
    return const VerifyOtpOut(
      needsSignup: false,
      token: TokenOut(accessToken: 't', user: testUser),
    );
  }

  @override
  Future<UserOut> completeSignup({
    required String ticket,
    required String name,
    String? email,
  }) async {
    signedIn = true;
    return UserOut(id: 2, name: name, phone: '+919000000001', email: email);
  }

  @override
  Future<void> logout() async => signedIn = false;
}

class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({
    this.settings = testSettings,
    this.serviceList = testServices,
  });
  BookingSettings settings;
  List<ServiceOut> serviceList;

  @override
  Future<List<ServiceOut>> services() async => serviceList;

  @override
  Future<ServiceOut> service(int id) async =>
      serviceList.firstWhere((s) => s.id == id);

  @override
  Future<BookingSettings> bookingSettings() async => settings;
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({List<FamilyMember>? family, List<Address>? addresses})
    : familyList = family ?? [testMember],
      addressList = addresses ?? [testAddress];
  final List<FamilyMember> familyList;
  final List<Address> addressList;
  int _nextId = 100;
  ApiException? deleteError;
  final deletedAddressIds = <int>[];
  bool deleteOtpSent = false;

  @override
  Future<UserOut> me() async => testUser;

  @override
  Future<UserOut> updateMe({String? name, String? email}) async => UserOut(
    id: 1,
    name: name ?? testUser.name,
    phone: testUser.phone,
    email: email,
  );

  @override
  Future<void> sendDeleteOtp() async => deleteOtpSent = true;

  @override
  Future<void> deleteAccount(String code) async {
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<List<FamilyMember>> family() async => List.of(familyList);

  @override
  Future<FamilyMember> addFamily(FamilyInput i) async {
    final m = FamilyMember(
      id: _nextId++,
      name: i.name,
      age: i.age,
      sex: i.sex,
      relation: i.relation,
      contactPhone: i.contactPhone,
      medicalNotes: i.medicalNotes,
    );
    familyList.add(m);
    return m;
  }

  @override
  Future<FamilyMember> updateFamily(int id, FamilyInput i) async {
    final idx = familyList.indexWhere((m) => m.id == id);
    final m = FamilyMember(
      id: id,
      name: i.name,
      age: i.age,
      sex: i.sex,
      relation: i.relation,
      contactPhone: i.contactPhone,
    );
    familyList[idx] = m;
    return m;
  }

  @override
  Future<void> deleteFamily(int id) async =>
      familyList.removeWhere((m) => m.id == id);

  @override
  Future<List<Address>> addresses() async => List.of(addressList);

  @override
  Future<Address> addAddress(AddressInput i) async {
    final a = Address(
      id: _nextId++,
      label: i.label,
      house: i.house,
      areaLine: i.areaLine,
      city: i.city,
      state: i.state,
      pincode: i.pincode,
      landmark: i.landmark,
      latitude: i.latitude,
      longitude: i.longitude,
      isDefault: i.isDefault,
    );
    addressList.add(a);
    return a;
  }

  @override
  Future<Address> updateAddress(int id, Json patch) async =>
      addressList.firstWhere((a) => a.id == id);

  @override
  Future<void> deleteAddress(int id) async {
    deletedAddressIds.add(id);
    addressList.removeWhere((a) => a.id == id);
  }
}

class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({
    this.maxHours = 12,
    this.gender = const GenderAvailability(male: true, female: true),
  });

  int maxHours;
  GenderAvailability gender;
  final createRequests = <BookingRequest>[];
  final bookings = <Booking>[];

  /// When set, the next create throws this.
  ApiException? createError;

  /// Hours (0-23) that are fully booked.
  Set<int> bookedHours = {16};
  List<Booking> current = [];
  List<Booking> history = [];

  @override
  Future<TimeGrid> timeGrid(int serviceId, DateTime day) async {
    final now = nowIst(fixedClock);
    return TimeGrid(
      date: isoDate(day),
      slots: [
        for (var h = 8; h < 20; h++)
          TimeSlot(
            hour: h,
            free: !bookedHours.contains(h),
            tooSoon: isTooSoon(
              day: day,
              hour: h,
              nowWall: now,
              minNoticeMinutes: 180,
            ),
          ),
      ],
    );
  }

  @override
  Future<int> maxDuration(int serviceId, DateTime day, int hour) async =>
      maxHours;

  @override
  Future<GenderAvailability> genderAvailability(
    int serviceId,
    DateTime day,
    int hour,
    int hours,
  ) async => gender;

  @override
  Future<Quote> quote(int serviceId, int hours) async => Quote(
    serviceId: serviceId,
    hours: hours,
    basePrice: 400,
    amount: 400 * hours,
  );

  @override
  Future<Booking> create(BookingRequest r) async {
    createRequests.add(r);
    if (createError != null) {
      final e = createError!;
      createError = null;
      throw e;
    }
    final b = makeBooking(
      id: 2000 + createRequests.length,
      holdExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
      amount: 400 * r.hours,
    );
    bookings.add(b);
    return b;
  }

  @override
  Future<List<Booking>> mine({required bool current}) async =>
      current ? this.current : history;

  @override
  Future<Booking> get(int id) async =>
      [...bookings, ...current, ...history].firstWhere((b) => b.id == id);
}

class FakePaymentRepository implements PaymentRepository {
  FakePaymentRepository(this.bookings);
  final FakeBookingRepository bookings;
  ApiException? orderError;
  String finalStatus = 'confirmed';
  final orders = <int>[];

  @override
  Future<OrderOut> createOrder(int bookingId) async {
    if (orderError != null) {
      final e = orderError!;
      orderError = null;
      throw e;
    }
    orders.add(bookingId);
    final b = bookings.bookings.firstWhere((b) => b.id == bookingId);
    return OrderOut(
      gateway: 'fake',
      orderId: 'order_$bookingId',
      amount: b.amount,
      keyId: 'fake',
      bookingId: bookingId,
      holdExpiresAt: b.holdExpiresAt,
    );
  }

  @override
  Future<FakePayOut> fakePay(int bookingId, String orderId) async =>
      FakePayOut(paymentId: 'pay_$bookingId', signature: 'sig');

  @override
  Future<Booking> verify({
    required int bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final b = bookings.bookings.firstWhere((b) => b.id == bookingId);
    return makeBooking(
      id: bookingId,
      status: finalStatus,
      nurseName: finalStatus == 'confirmed' ? 'Anita S.' : null,
      amount: b.amount,
      refund: finalStatus == 'cancelled'
          ? RefundOut(amount: b.amount, status: 'refund_pending')
          : null,
      cancelledBy: finalStatus == 'cancelled' ? 'system' : null,
    );
  }
}
