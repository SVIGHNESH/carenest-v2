import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/models/models.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/tell_us_screen.dart';
import 'features/booking/confirmed_screen.dart';
import 'features/booking/details_screen.dart';
import 'features/booking/duration_screen.dart';
import 'features/booking/gender_screen.dart';
import 'features/booking/patient_screen.dart';
import 'features/booking/review_screen.dart';
import 'features/booking/when_screen.dart';
import 'features/bookings/booking_detail_screen.dart';
import 'features/bookings/bookings_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/service_detail_screen.dart';
import 'features/home/services_screen.dart';
import 'features/home/shell.dart';
import 'features/map/map_picker_screen.dart';
import 'features/profile/address_form_screen.dart';
import 'features/profile/addresses_screen.dart';
import 'features/profile/delete_account_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/profile/family_screens.dart';
import 'features/profile/profile_screen.dart';
import 'features/splash/splash_screen.dart';
import 'state/auth_controller.dart';

const _authPaths = {'/login', '/otp', '/tell-us'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  String? needs<T>(GoRouterState s) => s.extra is T ? null : '/login';

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      switch (auth.status) {
        case AuthStatus.unknown:
          return loc == '/splash' ? null : '/splash';
        case AuthStatus.signedOut:
          return _authPaths.contains(loc) ? null : '/login';
        case AuthStatus.signedIn:
          return (loc == '/splash' || _authPaths.contains(loc))
              ? '/home'
              : null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        redirect: (_, s) => needs<String>(s),
        builder: (_, s) => OtpScreen(phone: s.extra! as String),
      ),
      GoRoute(
        path: '/tell-us',
        redirect: (_, s) => needs<String>(s),
        builder: (_, s) => TellUsScreen(ticket: s.extra! as String),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/services',
                builder: (_, _) => const ServicesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookings',
                builder: (_, _) => const BookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/services/:id',
        builder: (_, s) =>
            ServiceDetailScreen(serviceId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/book/patient',
        name: 'book-patient',
        builder: (_, _) => const PatientScreen(),
      ),
      GoRoute(
        path: '/book/when',
        name: 'book-when',
        builder: (_, _) => const WhenScreen(),
      ),
      GoRoute(
        path: '/book/duration',
        name: 'book-duration',
        builder: (_, _) => const DurationScreen(),
      ),
      GoRoute(
        path: '/book/nurse',
        name: 'book-nurse',
        builder: (_, _) => const GenderScreen(),
      ),
      GoRoute(
        path: '/book/details',
        name: 'book-details',
        builder: (_, _) => const DetailsScreen(),
      ),
      GoRoute(
        path: '/book/review',
        name: 'book-review',
        builder: (_, _) => const ReviewScreen(),
      ),
      GoRoute(
        path: '/book/confirmed/:id',
        builder: (_, s) => ConfirmedScreen(
          bookingId: int.parse(s.pathParameters['id']!),
          initial: s.extra is Booking ? s.extra! as Booking : null,
        ),
      ),
      GoRoute(
        path: '/map',
        builder: (_, s) => MapPickerScreen(
          args: s.extra is MapPickerArgs
              ? s.extra! as MapPickerArgs
              : const MapPickerArgs(),
        ),
      ),
      GoRoute(
        path: '/address-details',
        redirect: (_, s) => needs<AddressFormArgs>(s),
        builder: (_, s) => AddressFormScreen(args: s.extra! as AddressFormArgs),
      ),
      GoRoute(
        path: '/bookings/:id',
        builder: (_, s) =>
            BookingDetailScreen(bookingId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/family',
        builder: (_, _) => const FamilyListScreen(),
      ),
      GoRoute(
        path: '/profile/family/edit',
        builder: (_, s) => FamilyFormScreen(
          member: s.extra is FamilyMember ? s.extra! as FamilyMember : null,
        ),
      ),
      GoRoute(
        path: '/profile/addresses',
        builder: (_, _) => const AddressesScreen(),
      ),
      GoRoute(
        path: '/profile/delete',
        builder: (_, _) => const DeleteAccountScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
