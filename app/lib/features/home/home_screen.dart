import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/auth_controller.dart';
import '../../state/providers.dart';
import '../../ui/error_text.dart';
import '../../ui/status.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'service_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(servicesProvider);
    ref.invalidate(bookingsProvider(true));
    await Future.wait([
      ref.read(servicesProvider.future).catchError((_) => <Never>[]),
      ref.read(bookingsProvider(true).future).catchError((_) => <Never>[]),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = context.cn;
    final user = ref.watch(authControllerProvider).user;
    final first = (user?.name ?? '').trim().split(RegExp(r'\s+')).first;
    final services = ref.watch(servicesProvider);
    final current = ref.watch(bookingsProvider(true));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: CnSpace.page,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l.greeting(first), style: t.headlineMedium),
                    ),
                  ),
                  const BrandMark(size: 40),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l.homeSubtitle,
                style: t.bodyMedium?.copyWith(color: c.muted),
              ),
              const SizedBox(height: CnSpace.xl),
              Row(
                children: [
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.add_circle_outline,
                      label: l.bookService,
                      filled: true,
                      onTap: () => context.go('/services'),
                    ),
                  ),
                  const SizedBox(width: CnSpace.md),
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.event_note_outlined,
                      label: l.myBookings,
                      onTap: () => context.go('/bookings'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CnSpace.xl),
              _SectionTitle(title: l.nextBooking),
              current.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: CnLoading(),
                ),
                error: (e, _) => CnBanner(
                  message: errorMessage(context, e),
                  tone: Tone.danger,
                  action: CnButton(
                    label: l.tryAgain,
                    kind: CnButtonKind.text,
                    expand: false,
                    onPressed: () => ref.invalidate(bookingsProvider(true)),
                  ),
                ),
                data: (list) => list.isEmpty
                    ? CnCard(
                        child: Text(
                          l.noUpcomingBooking,
                          style: t.bodyMedium?.copyWith(color: c.muted),
                        ),
                      )
                    : CnCard(
                        onTap: () => context.push('/bookings/${list.first.id}'),
                        semanticLabel:
                            '${list.first.serviceName}, ${whenLabel(list.first.slotStart)}',
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    whenLabel(list.first.slotStart),
                                    style: t.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      list.first.serviceName,
                                      if (list.first.nurseName != null)
                                        list.first.nurseName!,
                                    ].join(', '),
                                    style: t.bodyMedium?.copyWith(
                                      color: c.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusChip(
                              label: bookingStatusLabel(l, list.first.status),
                              tone: bookingStatusTone(list.first.status),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: CnSpace.xl),
              _SectionTitle(
                title: l.services,
                action: l.viewAll,
                onAction: () => context.go('/services'),
              ),
              services.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: CnLoading(),
                ),
                error: (e, _) => CnBanner(
                  message: errorMessage(context, e),
                  tone: Tone.danger,
                  action: CnButton(
                    label: l.tryAgain,
                    kind: CnButtonKind.text,
                    expand: false,
                    onPressed: () => ref.invalidate(servicesProvider),
                  ),
                ),
                data: (list) => list.isEmpty
                    ? CnCard(
                        child: Text(
                          l.noServices,
                          style: t.bodyMedium?.copyWith(color: c.muted),
                        ),
                      )
                    : Column(
                        children: [
                          for (final s in list.take(4)) ...[
                            ServiceTile(
                              service: s,
                              onTap: () => context.push('/services/${s.id}'),
                            ),
                            const SizedBox(height: CnSpace.sm),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CnSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (action != null)
            CnButton(
              label: action!,
              kind: CnButtonKind.text,
              expand: false,
              onPressed: onAction,
            ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    return CnCard(
      onTap: onTap,
      semanticLabel: label,
      color: filled ? c.accent : null,
      padding: const EdgeInsets.symmetric(horizontal: CnSpace.lg, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: filled ? c.accentFg : c.accentText, size: 26),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: filled ? c.accentFg : c.fg, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
