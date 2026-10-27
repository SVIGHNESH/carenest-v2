import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/ist.dart';
import '../../data/models/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/booking_draft.dart';
import '../../state/providers.dart';
import '../../ui/async_body.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'flow_widgets.dart';

/// Step 2: day chips and the hour grid.
class WhenScreen extends ConsumerStatefulWidget {
  const WhenScreen({super.key});

  @override
  ConsumerState<WhenScreen> createState() => _WhenScreenState();
}

class _WhenScreenState extends ConsumerState<WhenScreen> {
  DateTime? _day;
  int? _hour;

  @override
  void initState() {
    super.initState();
    final d = ref.read(bookingDraftProvider);
    _day = d.day;
    _hour = d.hour;
  }

  String _noticeText(AppLocalizations l, int minutes) {
    if (minutes % 60 == 0) return l.noticeHours(minutes ~/ 60);
    return l.noticeMinutes(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.cn;
    final t = Theme.of(context).textTheme;
    final draft = ref.watch(bookingDraftProvider);
    final notice = ref.watch(flowNoticeProvider);
    final settings = ref.watch(bookingSettingsProvider);
    final clock = ref.watch(clockProvider);
    final nowWall = nowIst(clock);
    final today = dateOnly(nowWall);
    final service = draft.service;

    return FlowScaffold(
      step: 2,
      title: l.stepWhenTitle,
      bottom: BottomActionBar(
        child: CnButton(
          label: l.continueLabel,
          onPressed: (_day != null && _hour != null)
              ? () {
                  ref
                      .read(bookingDraftProvider.notifier)
                      .setSlot(_day!, _hour!);
                  ref.read(flowNoticeProvider.notifier).clear();
                  context.push('/book/duration');
                }
              : null,
        ),
      ),
      body: AsyncBody<BookingSettings>(
        value: settings,
        onRefresh: () async => ref.invalidate(bookingSettingsProvider),
        builder: (context, cfg) {
          final days = [
            for (var i = 0; i <= cfg.bookingWindowDays; i++) addDays(today, i),
          ];
          final day = (_day != null && days.contains(_day))
              ? _day!
              : days.first;
          final grid = ref.watch(
            timeGridProvider((serviceId: service!.id, date: isoDate(day))),
          );

          return ListView(
            padding: CnSpace.page,
            children: [
              if (notice != null) ...[
                CnBanner(
                  message: flowNoticeText(l, notice),
                  tone: Tone.warning,
                ),
                const SizedBox(height: CnSpace.lg),
              ],
              Semantics(
                header: true,
                child: Text(l.pickADay, style: t.titleMedium),
              ),
              const SizedBox(height: CnSpace.md),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (_, _) => const SizedBox(width: CnSpace.sm),
                  itemBuilder: (_, i) => _DayChip(
                    day: days[i],
                    selected: days[i] == day,
                    onTap: () => setState(() {
                      if (_day != days[i]) _hour = null;
                      _day = days[i];
                    }),
                  ),
                ),
              ),
              const SizedBox(height: CnSpace.xl),
              Semantics(
                header: true,
                child: Text(l.startTime, style: t.titleMedium),
              ),
              const SizedBox(height: CnSpace.md),
              grid.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: CnLoading(),
                ),
                error: (e, _) => CnBanner(
                  message: l.couldNotLoadTimes,
                  tone: Tone.danger,
                  action: CnButton(
                    label: l.tryAgain,
                    kind: CnButtonKind.text,
                    expand: false,
                    onPressed: () => ref.invalidate(
                      timeGridProvider((
                        serviceId: service.id,
                        date: isoDate(day),
                      )),
                    ),
                  ),
                ),
                data: (g) {
                  // Drop a stale selection that is no longer bookable.
                  final sel =
                      g.slots
                          .where((s) => s.hour == _hour && s.selectable)
                          .isNotEmpty
                      ? _hour
                      : null;
                  if (sel != _hour) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => mounted ? setState(() => _hour = sel) : null,
                    );
                  }
                  if (g.slots.isEmpty) {
                    return CnMessageViewInline(
                      icon: Icons.event_busy_outlined,
                      title: l.noTimesThisDay,
                      body: l.noTimesThisDayBody,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: CnSpace.sm,
                        crossAxisSpacing: CnSpace.sm,
                        childAspectRatio: 2.3,
                        children: [
                          for (final s in g.slots)
                            _HourChip(
                              slot: s,
                              selected: _hour == s.hour && day == _day,
                              onTap: s.selectable
                                  ? () => setState(() {
                                      _day = day;
                                      _hour = s.hour;
                                    })
                                  : null,
                            ),
                        ],
                      ),
                      const SizedBox(height: CnSpace.lg),
                      if (day == today) ...[
                        Builder(
                          builder: (_) {
                            final earliest = nowWall.add(
                              Duration(minutes: cfg.minNoticeMinutes),
                            );
                            final hour =
                                earliest.minute > 0 || earliest.second > 0
                                ? earliest.hour + 1
                                : earliest.hour;
                            final sameDay =
                                DateTime(
                                  earliest.year,
                                  earliest.month,
                                  earliest.day,
                                ) ==
                                today;
                            return Text(
                              sameDay && hour < 24
                                  ? '${l.earliestStartToday(hourLabel(hour))} ${l.noticeHint(_noticeText(l, cfg.minNoticeMinutes))}'
                                  : l.noticeHint(
                                      _noticeText(l, cfg.minNoticeMinutes),
                                    ),
                              style: t.bodySmall?.copyWith(color: c.fg2),
                            );
                          },
                        ),
                      ] else
                        Text(
                          l.noticeHint(_noticeText(l, cfg.minNoticeMinutes)),
                          style: t.bodySmall?.copyWith(color: c.fg2),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class CnMessageViewInline extends StatelessWidget {
  const CnMessageViewInline({
    super.key,
    required this.icon,
    required this.title,
    this.body,
  });
  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, color: c.muted, size: 32),
          const SizedBox(height: 12),
          Text(title, style: t.titleSmall, textAlign: TextAlign.center),
          if (body != null) ...[
            const SizedBox(height: 4),
            Text(
              body!,
              style: t.bodyMedium?.copyWith(color: c.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });
  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    final t = Theme.of(context).textTheme;
    final fg = selected ? c.accentFg : c.fg;
    return Semantics(
      button: true,
      selected: selected,
      label: dayLabel(day),
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
          child: SizedBox(
            width: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  shortDayParts(day, weekday: true),
                  style: t.labelMedium?.copyWith(
                    color: selected ? c.accentFg : c.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  shortDayParts(day, weekday: false),
                  style: t.titleLarge?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HourChip extends StatelessWidget {
  const _HourChip({
    required this.slot,
    required this.selected,
    required this.onTap,
  });
  final TimeSlot slot;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    final l = AppLocalizations.of(context);
    final enabled = onTap != null;
    final label = hourLabel(slot.hour);
    final reason = slot.tooSoon
        ? l.tooSoonShort
        : (!slot.free ? l.bookedShort : null);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: reason == null ? label : '$label, $reason',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? c.accent : (enabled ? c.surface : c.sunken),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CnSpace.radius),
          side: BorderSide(
            color: selected ? c.accent : (enabled ? c.borderStrong : c.border),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CnSpace.radius),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: selected ? c.accentFg : (enabled ? c.fg : c.subtle),
                decoration: enabled ? null : TextDecoration.lineThrough,
                decorationColor: c.subtle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
