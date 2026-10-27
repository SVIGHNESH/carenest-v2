import '../l10n/gen/app_localizations.dart';
import 'widgets.dart';

/// Human label for a booking status. Unknown values read as plain words.
String bookingStatusLabel(AppLocalizations l, String status) =>
    switch (status) {
      'pending_payment' => l.statusPendingPayment,
      'expired' => l.statusExpired,
      'confirmed' => l.statusConfirmed,
      'in_progress' => l.statusInProgress,
      'completed' => l.statusCompleted,
      'cancelled' => l.statusCancelled,
      _ => status.replaceAll('_', ' '),
    };

Tone bookingStatusTone(String status) => switch (status) {
  'confirmed' => Tone.accent,
  'in_progress' => Tone.info,
  'completed' => Tone.success,
  'cancelled' => Tone.danger,
  'pending_payment' => Tone.warning,
  _ => Tone.neutral,
};

String refundStatusLabel(AppLocalizations l, String status) =>
    status == 'refunded' ? l.refundSent : l.refundInProgress;

String genderLabel(AppLocalizations l, String gender) =>
    gender == 'male' ? l.maleNurse : l.femaleNurse;

String sexLabel(AppLocalizations l, String? sex) => switch (sex) {
  'male' => l.sexMale,
  'female' => l.sexFemale,
  'other' => l.sexOther,
  _ => '',
};
