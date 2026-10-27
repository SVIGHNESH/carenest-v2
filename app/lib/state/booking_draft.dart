import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import 'providers.dart';

const _keep = Object();

/// An address the user picked on the map but has not saved yet.
class PendingLocation {
  const PendingLocation({
    required this.latitude,
    required this.longitude,
    required this.areaLine,
    required this.city,
    required this.state,
    required this.pincode,
  });
  final double latitude, longitude;
  final String areaLine, city, state, pincode;

  String get summary =>
      [areaLine, city, state, pincode].where((p) => p.isNotEmpty).join(', ');
}

/// Everything chosen so far in the booking flow.
class BookingDraft {
  const BookingDraft({
    this.service,
    this.member,
    this.forSelf = true,
    this.patientName = '',
    this.patientAge,
    this.patientSex,
    this.condition = '',
    this.contactPhone = '',
    this.day,
    this.hour,
    this.hours,
    this.gender,
    this.address,
    this.addressIsTemporary = false,
    this.pendingLocation,
    this.createdBooking,
  });

  final ServiceOut? service;
  final FamilyMember? member;
  final bool forSelf;
  final String patientName;
  final int? patientAge;
  final String? patientSex;
  final String condition;
  final String contactPhone;
  final DateTime? day;
  final int? hour;
  final int? hours;
  final String? gender;
  final Address? address;

  /// The address was created only to book; it is removed after the booking is made.
  final bool addressIsTemporary;
  final PendingLocation? pendingLocation;

  /// Booking already created for this draft (waiting for payment).
  final Booking? createdBooking;

  bool get hasSlot => day != null && hour != null;

  BookingDraft copyWith({
    Object? service = _keep,
    Object? member = _keep,
    bool? forSelf,
    String? patientName,
    Object? patientAge = _keep,
    Object? patientSex = _keep,
    String? condition,
    String? contactPhone,
    Object? day = _keep,
    Object? hour = _keep,
    Object? hours = _keep,
    Object? gender = _keep,
    Object? address = _keep,
    bool? addressIsTemporary,
    Object? pendingLocation = _keep,
    Object? createdBooking = _keep,
  }) {
    return BookingDraft(
      service: identical(service, _keep)
          ? this.service
          : service as ServiceOut?,
      member: identical(member, _keep) ? this.member : member as FamilyMember?,
      forSelf: forSelf ?? this.forSelf,
      patientName: patientName ?? this.patientName,
      patientAge: identical(patientAge, _keep)
          ? this.patientAge
          : patientAge as int?,
      patientSex: identical(patientSex, _keep)
          ? this.patientSex
          : patientSex as String?,
      condition: condition ?? this.condition,
      contactPhone: contactPhone ?? this.contactPhone,
      day: identical(day, _keep) ? this.day : day as DateTime?,
      hour: identical(hour, _keep) ? this.hour : hour as int?,
      hours: identical(hours, _keep) ? this.hours : hours as int?,
      gender: identical(gender, _keep) ? this.gender : gender as String?,
      address: identical(address, _keep) ? this.address : address as Address?,
      addressIsTemporary: addressIsTemporary ?? this.addressIsTemporary,
      pendingLocation: identical(pendingLocation, _keep)
          ? this.pendingLocation
          : pendingLocation as PendingLocation?,
      createdBooking: identical(createdBooking, _keep)
          ? this.createdBooking
          : createdBooking as Booking?,
    );
  }
}

/// Why the flow sent the user back to the date and time step.
enum FlowNotice {
  noNurseFree,
  holdExpired,
  paused,
  tooSoon,
  tooFar,
  crossesMidnight,
  other,
}

FlowNotice? flowNoticeForCode(String? code) => switch (code) {
  'no_nurse_free' => FlowNotice.noNurseFree,
  'hold_expired' => FlowNotice.holdExpired,
  'paused' => FlowNotice.paused,
  'too_soon' => FlowNotice.tooSoon,
  'too_far' => FlowNotice.tooFar,
  'crosses_midnight' => FlowNotice.crossesMidnight,
  _ => null,
};

final flowNoticeProvider = NotifierProvider<FlowNoticeController, FlowNotice?>(
  FlowNoticeController.new,
);

class FlowNoticeController extends Notifier<FlowNotice?> {
  @override
  FlowNotice? build() => null;
  void show(FlowNotice n) => state = n;
  void clear() => state = null;
}

final bookingDraftProvider =
    NotifierProvider<BookingDraftController, BookingDraft>(
      BookingDraftController.new,
    );

class BookingDraftController extends Notifier<BookingDraft> {
  @override
  BookingDraft build() => const BookingDraft();

  /// Always begins a fresh booking.
  void start(ServiceOut service) {
    discardTemporaryAddress();
    state = BookingDraft(service: service);
    ref.read(flowNoticeProvider.notifier).clear();
  }

  void reset() {
    discardTemporaryAddress();
    state = const BookingDraft();
    ref.read(flowNoticeProvider.notifier).clear();
  }

  /// Removes an address that was created only for this booking (best effort).
  void discardTemporaryAddress() {
    final a = state.address;
    if (!state.addressIsTemporary || a == null) return;
    state = state.copyWith(address: null, addressIsTemporary: false);
    ref
        .read(profileRepositoryProvider)
        .deleteAddress(a.id)
        .then((_) => ref.invalidate(addressesProvider))
        .catchError((_) {});
  }

  void setPatientSelf({required String name, required String phone}) {
    state = state.copyWith(
      member: null,
      forSelf: true,
      patientName: name,
      patientAge: null,
      patientSex: null,
      contactPhone: phone,
      createdBooking: null,
    );
  }

  void setPatientMember(FamilyMember m, {required String fallbackPhone}) {
    final phone = (m.contactPhone != null && m.contactPhone!.isNotEmpty)
        ? m.contactPhone!
        : fallbackPhone;
    state = state.copyWith(
      member: m,
      forSelf: false,
      patientName: m.name,
      patientAge: m.age,
      patientSex: m.sex,
      condition: m.medicalNotes ?? '',
      contactPhone: phone,
      createdBooking: null,
    );
  }

  /// Changing the start invalidates the duration and gender chosen for the old one.
  void setSlot(DateTime day, int hour) {
    final same = state.day == day && state.hour == hour;
    state = state.copyWith(
      day: day,
      hour: hour,
      hours: same ? state.hours : null,
      gender: same ? state.gender : null,
      createdBooking: null,
    );
  }

  void setHours(int hours) {
    state = state.copyWith(
      hours: hours,
      gender: state.hours == hours ? state.gender : null,
      createdBooking: null,
    );
  }

  void setGender(String gender) =>
      state = state.copyWith(gender: gender, createdBooking: null);

  void setPatientDetails({
    required String name,
    required int? age,
    required String? sex,
    required String condition,
    required String phone,
  }) {
    state = state.copyWith(
      patientName: name,
      patientAge: age,
      patientSex: sex,
      condition: condition,
      contactPhone: phone,
      createdBooking: null,
    );
  }

  /// Picks [a] for the booking; keeps the "temporary" flag if it is the address
  /// created in this flow.
  void selectAddress(Address a) {
    if (state.addressIsTemporary && state.address?.id != a.id) {
      discardTemporaryAddress();
    }
    final keepTemp = state.addressIsTemporary && state.address?.id == a.id;
    state = state.copyWith(
      address: a,
      addressIsTemporary: keepTemp,
      pendingLocation: null,
      createdBooking: null,
    );
  }

  void chooseSavedAddress(Address a) => state = state.copyWith(
    address: a,
    addressIsTemporary: false,
    pendingLocation: null,
    createdBooking: null,
  );

  void setPendingLocation(PendingLocation? p) =>
      state = state.copyWith(pendingLocation: p);

  /// Address created from the map and details screens.
  void useCreatedAddress(Address a, {required bool temporary}) =>
      state = state.copyWith(
        address: a,
        addressIsTemporary: temporary,
        pendingLocation: null,
        createdBooking: null,
      );

  void setCreatedBooking(Booking? b) =>
      state = state.copyWith(createdBooking: b);
}
