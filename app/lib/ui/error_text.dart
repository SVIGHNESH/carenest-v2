import 'package:flutter/widgets.dart';

import '../data/api/api_exception.dart';
import '../l10n/gen/app_localizations.dart';

/// Human message for any error: the backend `detail` when present,
/// otherwise a localized fallback by error kind.
String errorMessage(BuildContext context, Object error) {
  final l = AppLocalizations.of(context);
  if (error is ApiException) {
    final m = error.message;
    if (m != null && m.trim().isNotEmpty) return m;
    return switch (error.kind) {
      ApiErrorKind.network => l.errorNetwork,
      ApiErrorKind.timeout => l.errorTimeout,
      ApiErrorKind.server => l.errorServer,
      ApiErrorKind.rateLimited => l.errorRateLimited,
      ApiErrorKind.notFound => l.errorNotFound,
      _ => l.errorGeneric,
    };
  }
  return l.errorGeneric;
}
