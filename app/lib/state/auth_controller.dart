import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/api_exception.dart';
import '../data/models/models.dart';
import 'booking_draft.dart';
import 'providers.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.startupFailed = false,
  });
  final AuthStatus status;
  final UserOut? user;

  /// The stored session could not be checked (no network); splash offers retry.
  final bool startupFailed;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  /// Called from the splash screen.
  Future<void> bootstrap() async {
    state = const AuthState();
    try {
      final user = await ref.read(authRepositoryProvider).restoreSession();
      state = user == null
          ? const AuthState(status: AuthStatus.signedOut)
          : AuthState(status: AuthStatus.signedIn, user: user);
    } on ApiException {
      state = const AuthState(startupFailed: true);
    }
  }

  void signedIn(UserOut user) =>
      state = AuthState(status: AuthStatus.signedIn, user: user);

  void updateUser(UserOut user) =>
      state = AuthState(status: AuthStatus.signedIn, user: user);

  /// A request came back 401: the session is gone, return to login.
  void sessionExpired() {
    if (state.status == AuthStatus.signedOut) return;
    _clearLocal();
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    _clearLocal();
  }

  /// After the account was deleted on the server.
  void accountDeleted() => _clearLocal();

  void _clearLocal() {
    ref.read(bookingDraftProvider.notifier).reset();
    state = const AuthState(status: AuthStatus.signedOut);
  }
}
