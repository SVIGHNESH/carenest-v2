import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/async_body.dart';
import '../../ui/error_text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../booking/details_screen.dart';
import '../map/map_picker_screen.dart';
import '../../state/booking_draft.dart';
import 'address_form_screen.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final pending = await context.push<PendingLocation>(
      '/map',
      extra: const MapPickerArgs(),
    );
    if (pending == null || !context.mounted) return;
    await context.push<Address>(
      '/address-details',
      extra: AddressFormArgs.forNew(pending),
    );
    ref.invalidate(addressesProvider);
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(addressesProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Address a) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteAddressTitle),
        content: Text(a.summary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.keep),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _run(
        context,
        ref,
        () => ref.read(profileRepositoryProvider).deleteAddress(a.id),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = context.cn;
    return Scaffold(
      appBar: AppBar(title: Text(l.addresses)),
      bottomNavigationBar: BottomActionBar(
        child: CnButton(
          label: l.addAddressPlus,
          icon: Icons.add,
          onPressed: () => _add(context, ref),
        ),
      ),
      body: AsyncBody<List<Address>>(
        value: ref.watch(addressesProvider),
        onRefresh: () async {
          ref.invalidate(addressesProvider);
          await ref
              .read(addressesProvider.future)
              .catchError((_) => <Address>[]);
        },
        isEmpty: (list) => list.isEmpty,
        emptyIcon: Icons.location_off_outlined,
        emptyTitle: l.noAddresses,
        emptyBody: l.noAddressesBody,
        builder: (context, list) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: CnSpace.page,
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: CnSpace.sm),
          itemBuilder: (_, i) {
            final a = list[i];
            return CnCard(
              onTap: () async {
                await context.push<Address>(
                  '/address-details',
                  extra: AddressFormArgs.forEdit(a),
                );
                ref.invalidate(addressesProvider);
              },
              padding: const EdgeInsets.only(
                left: CnSpace.lg,
                top: 8,
                bottom: 8,
                right: 4,
              ),
              semanticLabel:
                  '${addressLabel(l, a.label)}, ${a.summary}${a.isDefault ? ', ${l.defaultLabel}' : ''}',
              child: Row(
                children: [
                  Icon(
                    a.label == 'Work'
                        ? Icons.work_outline
                        : Icons.home_outlined,
                    color: c.fg2,
                  ),
                  const SizedBox(width: CnSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                addressLabel(l, a.label),
                                style: t.titleSmall?.copyWith(fontSize: 15),
                              ),
                            ),
                            if (a.isDefault) ...[
                              const SizedBox(width: 8),
                              StatusChip(
                                label: l.defaultLabel,
                                tone: Tone.accent,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          a.summary,
                          style: t.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: l.moreActions,
                    icon: Icon(Icons.more_vert, color: c.muted),
                    constraints: const BoxConstraints(minWidth: 180),
                    onSelected: (v) {
                      if (v == 'default') {
                        _run(
                          context,
                          ref,
                          () => ref
                              .read(profileRepositoryProvider)
                              .updateAddress(a.id, {'is_default': true}),
                        );
                      } else {
                        _delete(context, ref, a);
                      }
                    },
                    itemBuilder: (_) => [
                      if (!a.isDefault)
                        PopupMenuItem(
                          value: 'default',
                          child: Text(l.setAsDefault),
                        ),
                      PopupMenuItem(value: 'delete', child: Text(l.delete)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
