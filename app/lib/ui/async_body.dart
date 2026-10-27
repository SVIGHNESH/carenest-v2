import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import 'error_text.dart';
import 'widgets.dart';

/// Renders an [AsyncValue] with loading, error (retry) and pull to refresh.
/// [builder] must return a scrollable (or use [emptyWhen] to show the empty view).
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.builder,
    this.isEmpty,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle,
    this.emptyBody,
    this.emptyAction,
    this.onEmptyAction,
  });

  final AsyncValue<T> value;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext, T) builder;
  final bool Function(T)? isEmpty;
  final IconData emptyIcon;
  final String? emptyTitle;
  final String? emptyBody;
  final String? emptyAction;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return value.when(
      skipLoadingOnRefresh: true,
      loading: () => const CnLoading(),
      error: (e, _) => RefreshIndicator(
        onRefresh: onRefresh,
        child: CnMessageView(
          icon: Icons.cloud_off_outlined,
          title: l.somethingWentWrong,
          body: errorMessage(context, e),
          actionLabel: l.tryAgain,
          onAction: onRefresh,
        ),
      ),
      data: (data) {
        if (isEmpty != null && isEmpty!(data)) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: CnMessageView(
              icon: emptyIcon,
              title: emptyTitle ?? l.nothingHere,
              body: emptyBody,
              actionLabel: emptyAction,
              onAction: onEmptyAction,
            ),
          );
        }
        return RefreshIndicator(onRefresh: onRefresh, child: builder(context, data));
      },
    );
  }
}
