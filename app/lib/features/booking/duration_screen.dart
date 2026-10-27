import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ist.dart';
import '../../core/money.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/booking_draft.dart';
import '../../state/providers.dart';
import '../../ui/async_body.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'flow_widgets.dart';

const maxBookingHours = 12;

/// Hours offered: 1 up to the smaller of 12 and what a nurse can cover.
List<int> offeredHours(int maxFromServer) {
  final top = maxFromServer.clamp(0, maxBookingHours);
  return [for (var h = 1; h <= top; h++) h];
}

/// Step 3: how many hours (1 to 12, capped by nurse availability).
class DurationScreen extends ConsumerStatefulWidget {
  const DurationScreen({super.key});

  @override
  ConsumerState<DurationScreen> createState() => _DurationScreenState();
}

class _DurationScreenState extends ConsumerState<DurationScreen> {
  int? _hours;

  @override
  void initState() {
    super.initState();
    _hours = ref.read(bookingDraftProvider).hours;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = context.cn;
    final draft = ref.watch(bookingDraftProvider);
    final service = draft.service!;
    final max = ref.watch(
      maxDurationProvider((
        serviceId: service.id,
        date: isoDate(draft.day!),
        hour: draft.hour!,
      )),
    );

    return FlowScaffold(
      step: 3,
      title: l.stepDurationTitle,
      bottom: BottomActionBar(
        child: CnButton(
          label: l.continueLabel,
          onPressed: _hours == null
              ? null
              : () {
                  ref.read(bookingDraftProvider.notifier).setHours(_hours!);
                  context.push('/book/nurse');
                },
        ),
      ),
      body: AsyncBody<int>(
        value: max,
        onRefresh: () async => ref.invalidate(maxDurationProvider),
        builder: (context, cap) {
          final options = offeredHours(cap);
          if (options.isEmpty) {
            return ListView(
              padding: CnSpace.page,
              children: [
                const FlowSummary(),
                CnMessageViewBlock(
                  title: l.noDurationTitle,
                  body: l.noDurationBody,
                  actionLabel: l.changeDateOrTime,
                  onAction: () => backToWhen(context),
                ),
              ],
            );
          }
          final selected = (_hours != null && options.contains(_hours))
              ? _hours
              : null;
          if (selected != _hours) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => mounted ? setState(() => _hours = selected) : null,
            );
          }
          return ListView(
            padding: CnSpace.page,
            children: [
              const FlowSummary(),
              const SizedBox(height: CnSpace.xl),
              Semantics(
                header: true,
                child: Text(l.howManyHours, style: t.titleMedium),
              ),
              const SizedBox(height: CnSpace.md),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: CnSpace.sm,
                crossAxisSpacing: CnSpace.sm,
                childAspectRatio: 1.5,
                children: [
                  for (final h in options)
                    _HoursChip(
                      hours: h,
                      selected: _hours == h,
                      onTap: () => setState(() => _hours = h),
                    ),
                ],
              ),
              if (cap < maxBookingHours) ...[
                const SizedBox(height: CnSpace.lg),
                Text(l.durationCapped(cap), style: t.bodySmall),
              ],
              const SizedBox(height: CnSpace.xl),
              if (_hours != null)
                CnCard(
                  color: c.accentSoft,
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.priceTimesHours(
                              rupees(service.basePrice),
                              _hours!,
                            ),
                            style: t.bodyMedium,
                          ),
                        ),
                        Text(
                          rupees(service.basePrice * _hours!),
                          style: t.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class CnMessageViewBlock extends StatelessWidget {
  const CnMessageViewBlock({
    super.key,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Icon(Icons.timer_off_outlined, size: 36, color: context.cn.muted),
          const SizedBox(height: 12),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, style: t.bodyMedium, textAlign: TextAlign.center),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            CnButton(
              label: actionLabel!,
              onPressed: onAction,
              kind: CnButtonKind.secondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _HoursChip extends StatelessWidget {
  const _HoursChip({
    required this.hours,
    required this.selected,
    required this.onTap,
  });
  final int hours;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: l.hoursCount(hours),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? c.accent : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CnSpace.radius),
          side: BorderSide(color: selected ? c.accent : c.borderStrong),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CnSpace.radius),
          child: Center(
            child: Text(
              '$hours',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: selected ? c.accentFg : c.fg),
            ),
          ),
        ),
      ),
    );
  }
}
