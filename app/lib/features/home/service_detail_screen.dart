import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../data/models/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/booking_draft.dart';
import '../../state/providers.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../../ui/async_body.dart';

final serviceProvider = FutureProvider.autoDispose.family<ServiceOut, int>(
  (ref, id) => ref.watch(catalogRepositoryProvider).service(id),
);

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});
  final int serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final service = ref.watch(serviceProvider(serviceId));
    final settings = ref.watch(bookingSettingsProvider);
    final paused = settings.asData?.value.bookingsPaused ?? false;
    final t = Theme.of(context).textTheme;
    final c = context.cn;

    return Scaffold(
      appBar: AppBar(title: Text(service.asData?.value.name ?? '')),
      body: AsyncBody<ServiceOut>(
        value: service,
        onRefresh: () async {
          ref.invalidate(serviceProvider(serviceId));
          ref.invalidate(bookingSettingsProvider);
        },
        builder: (context, s) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: CnSpace.page,
          children: [
            Semantics(
              header: true,
              child: Text(s.name, style: t.headlineMedium),
            ),
            const SizedBox(height: 6),
            Text(
              l.pricePerHour(rupees(s.basePrice)),
              style: t.titleMedium?.copyWith(color: c.accentText),
            ),
            const SizedBox(height: CnSpace.lg),
            Text(s.description, style: t.bodyLarge),
            const SizedBox(height: CnSpace.xl),
            if (paused)
              CnBanner(message: l.bookingsPausedBanner, tone: Tone.warning),
            if (!s.available && !paused)
              CnBanner(message: l.notAvailableNow, tone: Tone.warning),
            const SizedBox(height: CnSpace.sm),
            Text(l.priceIncludesTax, style: t.bodySmall),
          ],
        ),
      ),
      bottomNavigationBar: service.asData == null
          ? null
          : BottomActionBar(
              child: CnButton(
                label: l.bookNow,
                onPressed: (service.asData!.value.available && !paused)
                    ? () {
                        ref
                            .read(bookingDraftProvider.notifier)
                            .start(service.asData!.value);
                        context.push('/book/patient');
                      }
                    : null,
              ),
            ),
    );
  }
}
