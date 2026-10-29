import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_core/saff_core.dart';

/// The user-facing message of [failure]; never an exception string.
String failureText(AppLocalizations l10n, AppFailure failure) =>
    _byKey(l10n, failure.code.messageKey) ?? l10n.errorUnknown;

String? _byKey(AppLocalizations l, String key) => switch (key) {
  'errorAlarmConflict' => l.errorAlarmConflict,
  'errorAlarmInvalid' => l.errorAlarmInvalid,
  'errorAlarmLimit' => l.errorAlarmLimit,
  'errorAlarmPermissionMissing' => l.errorAlarmPermissionMissing,
  'errorAlreadyMember' => l.errorAlreadyMember,
  'errorAuthCancelled' => l.errorAuthCancelled,
  'errorInviteInvalid' => l.errorInviteInvalid,
  'errorNetworkOffline' => l.errorNetworkOffline,
  'errorNetworkTimeout' => l.errorNetworkTimeout,
  'errorNotFound' => l.errorNotFound,
  'errorNotParticipant' => l.errorNotParticipant,
  'errorNotSaffOwner' => l.errorNotSaffOwner,
  'errorInvalidArgument' => l.errorInvalidArgument,
  _ => _more(l, key),
};

String? _more(AppLocalizations l, String key) => switch (key) {
  'errorSaffFull' => l.errorSaffFull,
  'errorSaffLimit' => l.errorSaffLimit,
  'errorSaffNotFound' => l.errorSaffNotFound,
  'errorSaffTooSmall' => l.errorSaffTooSmall,
  'errorProposalExpired' => l.errorProposalExpired,
  'errorProposalNotPending' => l.errorProposalNotPending,
  'errorProposalSuperseded' => l.errorProposalSuperseded,
  'errorSkipLimit' => l.errorSkipLimit,
  'errorSkipTooLate' => l.errorSkipTooLate,
  'errorNudgeLimit' => l.errorNudgeLimit,
  'errorNudgeTargetDone' => l.errorNudgeTargetDone,
  'errorNudgeTooSoon' => l.errorNudgeTooSoon,
  'errorRoundClosed' => l.errorRoundClosed,
  'errorRoundLocked' => l.errorRoundLocked,
  'errorPermissionDenied' => l.errorPermissionDenied,
  'errorUnauthenticated' => l.errorUnauthenticated,
  'errorServerUnavailable' => l.errorServerUnavailable,
  'errorServerInternal' => l.errorServerInternal,
  'errorPhoneInvalid' => l.errorPhoneInvalid,
  'errorProfileNameInvalid' => l.errorProfileNameInvalid,
  _ => null,
};
