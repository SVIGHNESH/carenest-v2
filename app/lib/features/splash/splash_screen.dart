import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../state/auth_controller.dart';
import '../../ui/widgets.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(authControllerProvider.notifier).bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final failed = ref.watch(authControllerProvider).startupFailed;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 240,
                  semanticLabel: l.appName,
                ),
              ),
              const SizedBox(height: 40),
              if (failed) ...[
                Text(l.errorNetwork, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                CnButton(
                  label: l.tryAgain,
                  expand: false,
                  kind: CnButtonKind.secondary,
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).bootstrap(),
                ),
              ] else
                const CnLoading(),
            ],
          ),
        ),
      ),
    );
  }
}
