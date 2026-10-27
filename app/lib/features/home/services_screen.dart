import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/async_body.dart';
import '../../ui/tokens.dart';
import 'service_tile.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.services)),
      body: AsyncBody(
        value: ref.watch(servicesProvider),
        onRefresh: () async {
          ref.invalidate(servicesProvider);
          await ref.read(servicesProvider.future).catchError((_) => <Never>[]);
        },
        isEmpty: (list) => list.isEmpty,
        emptyIcon: Icons.medical_services_outlined,
        emptyTitle: l.noServices,
        emptyBody: l.noServicesBody,
        builder: (context, list) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: CnSpace.page,
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: CnSpace.sm),
          itemBuilder: (_, i) => ServiceTile(
            service: list[i],
            onTap: () => context.push('/services/${list[i].id}'),
          ),
        ),
      ),
    );
  }
}
