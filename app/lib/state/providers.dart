import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/env.dart';
import '../core/ist.dart';
import '../data/api/api_client.dart';
import '../data/api/token_store.dart';
import '../data/models/models.dart';
import '../data/repositories/repositories.dart';
import '../services/location_service.dart';
import '../services/otp_autofill.dart';
import '../services/payment/payment_launcher.dart';
import '../services/payment/razorpay_launcher.dart';
import '../services/places_service.dart';
import '../features/payment/fake_payment_launcher.dart';
import 'auth_controller.dart';

// ---- infrastructure (overridden in main and in tests)
final clockProvider = Provider<Clock>((ref) => systemClock);
final tokenStoreProvider = Provider<TokenStore>((ref) => MemoryTokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: Env.apiBaseUrl,
    tokens: ref.watch(tokenStoreProvider),
    onUnauthorized: () =>
        ref.read(authControllerProvider.notifier).sessionExpired(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => HttpAuthRepository(ref.watch(apiClientProvider)),
);
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => HttpProfileRepository(ref.watch(apiClientProvider)),
);
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => HttpCatalogRepository(ref.watch(apiClientProvider)),
);
final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => HttpBookingRepository(ref.watch(apiClientProvider)),
);
final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => HttpPaymentRepository(ref.watch(apiClientProvider)),
);

final placesServiceProvider = Provider<PlacesService>(
  (ref) => Env.hasMapsKey
      ? GooglePlacesService(Env.mapsApiKey)
      : const FakePlacesService(),
);
final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);
final otpAutofillProvider = Provider<OtpAutofill>((ref) => SmsOtpAutofill());
final paymentLauncherProvider = Provider<PaymentLauncher>(
  (ref) => const RoutingPaymentLauncher(
    fake: FakePaymentLauncher(),
    razorpay: RazorpayPaymentLauncher(),
  ),
);

/// Opens a phone dialer or web page; replaced in tests.
final uriLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

// ---- server data
final servicesProvider = FutureProvider.autoDispose<List<ServiceOut>>(
  (ref) => ref.watch(catalogRepositoryProvider).services(),
);

final bookingSettingsProvider = FutureProvider.autoDispose<BookingSettings>(
  (ref) => ref.watch(catalogRepositoryProvider).bookingSettings(),
);

final familyProvider = FutureProvider.autoDispose<List<FamilyMember>>(
  (ref) => ref.watch(profileRepositoryProvider).family(),
);

final addressesProvider = FutureProvider.autoDispose<List<Address>>(
  (ref) => ref.watch(profileRepositoryProvider).addresses(),
);

/// `true` = Current tab, `false` = History tab.
final bookingsProvider = FutureProvider.autoDispose.family<List<Booking>, bool>(
  (ref, current) => ref.watch(bookingRepositoryProvider).mine(current: current),
);

final bookingProvider = FutureProvider.autoDispose.family<Booking, int>(
  (ref, id) => ref.watch(bookingRepositoryProvider).get(id),
);

typedef GridKey = ({int serviceId, String date});
typedef SlotKey = ({int serviceId, String date, int hour});
typedef GenderKey = ({int serviceId, String date, int hour, int hours});

final timeGridProvider = FutureProvider.autoDispose.family<TimeGrid, GridKey>(
  (ref, k) => ref
      .watch(bookingRepositoryProvider)
      .timeGrid(k.serviceId, DateTime.parse(k.date)),
);

final maxDurationProvider = FutureProvider.autoDispose.family<int, SlotKey>(
  (ref, k) => ref
      .watch(bookingRepositoryProvider)
      .maxDuration(k.serviceId, DateTime.parse(k.date), k.hour),
);

final genderAvailabilityProvider = FutureProvider.autoDispose
    .family<GenderAvailability, GenderKey>(
      (ref, k) => ref
          .watch(bookingRepositoryProvider)
          .genderAvailability(
            k.serviceId,
            DateTime.parse(k.date),
            k.hour,
            k.hours,
          ),
    );

typedef QuoteKey = ({int serviceId, int hours});
final quoteProvider = FutureProvider.autoDispose.family<Quote, QuoteKey>(
  (ref, k) => ref.watch(bookingRepositoryProvider).quote(k.serviceId, k.hours),
);
