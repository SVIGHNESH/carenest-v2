import 'package:carenest/app.dart';
import 'package:carenest/data/api/token_store.dart';
import 'package:carenest/services/location_service.dart';
import 'package:carenest/services/geo.dart';
import 'package:carenest/services/otp_autofill.dart';
import 'package:carenest/state/providers.dart';
import 'package:carenest/l10n/gen/app_localizations.dart';
import 'package:carenest/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class FakeLocationService implements LocationService {
  LocationException? error;
  @override
  Future<GeoPoint> current() async {
    if (error != null) throw error!;
    return const GeoPoint(28.3670, 79.4304);
  }
}

class TestEnv {
  TestEnv({bool signedIn = true})
    : auth = FakeAuthRepository(signedIn: signedIn),
      catalog = FakeCatalogRepository(),
      profile = FakeProfileRepository(),
      bookings = FakeBookingRepository() {
    payments = FakePaymentRepository(bookings);
  }
  final FakeAuthRepository auth;
  final FakeCatalogRepository catalog;
  final FakeProfileRepository profile;
  final FakeBookingRepository bookings;
  late final FakePaymentRepository payments;
  final launched = <Uri>[];
  final location = FakeLocationService();

  List<Override> get overrides => [
    clockProvider.overrideWithValue(fixedClock),
    tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    authRepositoryProvider.overrideWithValue(auth),
    catalogRepositoryProvider.overrideWithValue(catalog),
    profileRepositoryProvider.overrideWithValue(profile),
    bookingRepositoryProvider.overrideWithValue(bookings),
    paymentRepositoryProvider.overrideWithValue(payments),
    otpAutofillProvider.overrideWithValue(const NoOtpAutofill()),
    locationServiceProvider.overrideWithValue(location),
    uriLauncherProvider.overrideWithValue((u) async {
      launched.add(u);
      return true;
    }),
  ];
}

/// Phone-sized window.
void usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<ProviderContainer> pumpApp(WidgetTester tester, TestEnv env) async {
  usePhone(tester);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: env.overrides,
      child: const CareNestApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CareNestApp)));
}

/// Renders one screen without the router (for navigation-free assertions).
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  TestEnv env,
  Widget screen, {
  void Function(ProviderContainer)? setup,
  ThemeData? theme,
}) async {
  usePhone(tester);
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: env.overrides,
  );
  addTearDown(container.dispose);
  setup?.call(container);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme ?? CnTheme.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
