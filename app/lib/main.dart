import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/secure_token_store.dart';
import 'state/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      // A failed request should show its error, not silently retry.
      retry: (_, _) => null,
      overrides: [tokenStoreProvider.overrideWithValue(SecureTokenStore())],
      child: const CareNestApp(),
    ),
  );
}
