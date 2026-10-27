import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/env.dart';
import '../../core/phone.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/auth_controller.dart';
import '../../state/providers.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.logoutTitle),
        content: Text(l.logoutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.stay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.logout),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = context.cn;
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      appBar: AppBar(title: Text(l.navProfile)),
      body: ListView(
        padding: CnSpace.page,
        children: [
          Row(
            children: [
              InitialsAvatar(name: user?.name ?? '', size: 64),
              const SizedBox(width: CnSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(user?.name ?? '', style: t.titleLarge),
                    ),
                    Text(
                      maskPhone(user?.phone),
                      style: t.bodyMedium?.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CnSpace.xl),
          _MenuTile(
            icon: Icons.person_outline,
            label: l.editProfile,
            onTap: () => context.push('/profile/edit'),
          ),
          _MenuTile(
            icon: Icons.groups_outlined,
            label: l.familyMembers,
            onTap: () => context.push('/profile/family'),
          ),
          _MenuTile(
            icon: Icons.location_on_outlined,
            label: l.addresses,
            onTap: () => context.push('/profile/addresses'),
          ),
          _MenuTile(
            icon: Icons.privacy_tip_outlined,
            label: l.privacyPolicy,
            trailing: Icons.open_in_new,
            onTap: () =>
                ref.read(uriLauncherProvider)(Uri.parse(Env.privacyPolicyUrl)),
          ),
          _MenuTile(
            icon: Icons.delete_outline,
            label: l.deleteAccount,
            onTap: () => context.push('/profile/delete'),
          ),
          const SizedBox(height: CnSpace.sm),
          _MenuTile(
            icon: Icons.logout,
            label: l.logout,
            danger: true,
            onTap: () => _logout(context, ref),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.trailing = Icons.chevron_right,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final IconData trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    return Padding(
      padding: const EdgeInsets.only(bottom: CnSpace.sm),
      child: CnCard(
        onTap: onTap,
        semanticLabel: label,
        padding: const EdgeInsets.symmetric(
          horizontal: CnSpace.lg,
          vertical: 14,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: Row(
            children: [
              Icon(icon, color: danger ? c.danger : c.fg2),
              const SizedBox(width: CnSpace.md),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontSize: 15, color: danger ? c.danger : c.fg),
                ),
              ),
              Icon(
                trailing,
                color: c.subtle,
                size: trailing == Icons.chevron_right ? 24 : 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
