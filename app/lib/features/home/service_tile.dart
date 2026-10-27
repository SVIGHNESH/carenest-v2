import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/models/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

class ServiceTile extends StatelessWidget {
  const ServiceTile({super.key, required this.service, required this.onTap});
  final ServiceOut service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.cn;
    final t = Theme.of(context).textTheme;
    final price = l.pricePerHour(rupees(service.basePrice));
    return CnCard(
      onTap: onTap,
      semanticLabel: [
        service.name,
        price,
        if (!service.available) l.notAvailableNow,
      ].join(', '),
      padding: const EdgeInsets.symmetric(horizontal: CnSpace.lg, vertical: 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.favorite_border_rounded, color: c.accentText),
              ),
            ),
            const SizedBox(width: CnSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: t.titleSmall?.copyWith(fontSize: 15),
                  ),
                  Text(price, style: t.bodySmall),
                ],
              ),
            ),
            if (!service.available) ...[
              StatusChip(label: l.notAvailableShort),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, color: c.subtle),
          ],
        ),
      ),
    );
  }
}
