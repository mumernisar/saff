# Error handling

One system, used everywhere: on the phone, in the native alarm module and on the server.

---

## 1. Goals

1. Every failure path is visible in code (types, not hidden exceptions).
2. Every failure the user can see has a clear message and, where possible, an action.
3. Bugs are never swallowed: they reach crash reporting with context.
4. Retry only what can succeed on retry; never duplicate a write.
5. Client and server share one catalog of error codes.

---

## 2. Taxonomy

| Kind | Examples | Recoverable? | Reported to Crashlytics? |
|---|---|---|---|
| **Domain** (a business rule said no) | `SAFF_FULL`, `INVITE_INVALID`, `SKIP_TOO_LATE`, `SKIP_LIMIT`, `PROPOSAL_EXPIRED`, `ROUND_LOCKED`, `NUDGE_TOO_SOON` | Yes, user changes something | No |
| **Network** | no connection, timeout, DNS, TLS | Yes, retry | No (counted in metrics only) |
| **Backend** | `permission-denied`, `unauthenticated`, `not-found`, `already-exists`, `aborted`/conflict, `resource-exhausted`, `unavailable`, `internal` | Depends on code | `internal`/`unknown` yes |
| **Device** | exact-alarm permission revoked, notifications off, full-screen intent denied, battery optimised, storage full | Yes, user fixes a setting | No |
| **Data** | malformed JSON, checksum mismatch, unsupported schema/pack version, unresolvable placeholder | Usually degrade | Yes (non-fatal) |
| **Programmer error** (bug) | `StateError`, `TypeError`, null assertion, failed `assert`, unhandled case | No | Yes (fatal or non-fatal) |

Dart's own distinction applies: `Exception` = expected, recoverable condition → becomes an `AppFailure`.
`Error` = bug → never caught by feature code; handled by global handlers (§8).

---

## 3. The failure model (`saff_core`)

```dart
/// Base of every expected failure in the app.
sealed class AppFailure {
  const AppFailure({required this.code, this.cause, this.stackTrace, this.context = const {}});
  final FailureCode code;            // generated from contracts/errors.json
  final Object? cause;               // original exception (never shown to users)
  final StackTrace? stackTrace;
  final Map<String, Object?> context;// redacted diagnostic data (ids, not personal data)

  bool get retryable => code.retryable;
  FailureSeverity get severity => code.severity;    // info | warning | error | critical
  String get messageKey => code.messageKey;          // ARB key for the user message
}

final class DomainFailure  extends AppFailure { ... }
final class NetworkFailure extends AppFailure { ... }
final class BackendFailure extends AppFailure { ... }
final class DeviceFailure  extends AppFailure { ... }   // carries a DeviceFix (which setting to open)
final class DataFailure    extends AppFailure { ... }
final class UnknownFailure extends AppFailure { ... }   // mapped from anything unrecognised; always reported
```

```dart
sealed class Result<T> {
  const Result();
  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(AppFailure failure) = Err<T>;
}
final class Ok<T>  extends Result<T> { const Ok(this.value);  final T value; }
final class Err<T> extends Result<T> { const Err(this.failure); final AppFailure failure; }
```
Helpers: `map`, `flatMap`, `fold`, `getOrNull`, `Result.guard(() async {...}, mapper)`.
Use exhaustive `switch` on results and failures; no `default` branch on sealed types.

---

## 4. Turning exceptions into failures: the mapper chain (factory)

Every repository converts exceptions through a **`FailureMapper`**, a chain of small mappers, each
recognising one family of exceptions. This is a factory: the concrete failure produced depends on the
runtime exception.

```dart
abstract interface class ExceptionMapper {
  /// Returns a failure if this mapper recognises [e], otherwise null.
  AppFailure? tryMap(Object e, StackTrace st, Map<String, Object?> context);
}

final class FailureMapper {
  FailureMapper(this._mappers);
  final List<ExceptionMapper> _mappers;

  AppFailure map(Object e, StackTrace st, {Map<String, Object?> context = const {}}) {
    for (final m in _mappers) {
      final f = m.tryMap(e, st, context);
      if (f != null) return f;
    }
    return UnknownFailure(code: FailureCode.unknown, cause: e, stackTrace: st, context: context);
  }
}
```

**Mappers (in order):**
| Mapper | Recognises | Produces |
|---|---|---|
| `AppFailureMapper` | an `AppFailure` thrown deliberately inside a service | itself |
| `FunctionsExceptionMapper` | `FirebaseFunctionsException` | `DomainFailure` if `details.code` is a catalog domain code, else `BackendFailure` by gRPC code |
| `FirestoreExceptionMapper` | `FirebaseException(plugin: cloud_firestore)` | `BackendFailure` (`permission-denied`, `unavailable`, ...) |
| `AuthExceptionMapper` | `FirebaseAuthException` | `DomainFailure` (`AUTH_LINK_EXPIRED`, `AUTH_CANCELLED`) or `BackendFailure` |
| `StorageExceptionMapper` | `FirebaseException(plugin: firebase_storage)` | `BackendFailure` / `DomainFailure(IMPORT_TOO_LARGE)` |
| `NetworkExceptionMapper` | `SocketException`, `TimeoutException`, `HandshakeException`, `http.ClientException` | `NetworkFailure` |
| `HttpStatusMapper` | our `HttpStatusException(status, body)` from the gateway client | 4xx → `DataFailure`/`DomainFailure`; 5xx → `BackendFailure` (retryable) |
| `PlatformExceptionMapper` | `PlatformException`/Pigeon `FlutterError` from `saff_alarm`, billing, device | `DeviceFailure` with a `DeviceFix` |
| `DriftExceptionMapper` | `SqliteException`, `DriftWrappedException` | `DataFailure` (`LOCAL_DB_*`) |
| `FormatExceptionMapper` | `FormatException`, `CheckedFromJsonException` | `DataFailure(DATA_MALFORMED)` |

Mappers are registered once in DI. Tests cover every mapper with real exception instances.

**Usage in a repository:**
```dart
Future<Result<void>> skipOccurrence(OccurrenceId id) => Result.guard(
  () => _functions.call(Callables.skipOccurrence, {'occurrenceId': id.value}),
  _mapper,
  context: {'op': 'skipOccurrence', 'occurrenceId': id.value},
);
```

---

## 5. The error catalog (`contracts/errors.json`)

Single source for every code, shared by Dart and TypeScript (generated by `tools/gen_contracts`).

```json
{
  "SKIP_TOO_LATE": {
    "kind": "domain", "severity": "info", "retryable": false,
    "httpsCode": "failed-precondition",
    "messageKey": "errorSkipTooLate",
    "description": "Skip requested less than SKIP_MIN_NOTICE before the occurrence."
  }
}
```

**Initial codes** (extend per stage; never rename a published code):

| Area | Codes |
|---|---|
| Generic | `UNKNOWN`, `NETWORK_OFFLINE`, `NETWORK_TIMEOUT`, `SERVER_UNAVAILABLE`, `SERVER_INTERNAL`, `PERMISSION_DENIED`, `UNAUTHENTICATED`, `NOT_FOUND`, `CONFLICT`, `RATE_LIMITED`, `APP_UPDATE_REQUIRED`, `INVALID_ARGUMENT` |
| Auth | `AUTH_CANCELLED`, `AUTH_LINK_EXPIRED`, `AUTH_LINK_INVALID`, `AUTH_ACCOUNT_DISABLED` |
| Profile | `PROFILE_NAME_INVALID`, `PHONE_INVALID` |
| Saff | `SAFF_FULL`, `SAFF_NOT_FOUND`, `SAFF_LIMIT`, `INVITE_INVALID`, `ALREADY_MEMBER`, `NOT_SAFF_OWNER`, `SAFF_TOO_SMALL` |
| Alarms | `ALARM_LIMIT`, `ALARM_INVALID`, `ALARM_CONFLICT`, `NOT_PARTICIPANT`, `PROPOSAL_EXPIRED`, `PROPOSAL_SUPERSEDED`, `PROPOSAL_NOT_PENDING`, `SKIP_TOO_LATE`, `SKIP_LIMIT` |
| Rounds | `ROUND_LOCKED`, `ROUND_NOT_READY`, `ROUND_CLOSED`, `RESULT_ALREADY_SUBMITTED`, `NUDGE_TOO_SOON`, `NUDGE_LIMIT`, `NUDGE_TARGET_DONE`, `PLANT_LIMIT`, `PLANT_TOO_LONG`, `PLANT_PAIRS_ONLY`, `SELFIE_UPLOAD_FAILED`, `REVIEW_LIMIT` |
| Content | `CONTENT_UNAVAILABLE`, `PACK_CHECKSUM_MISMATCH`, `PACK_VERSION_UNSUPPORTED`, `PLACEHOLDER_UNRESOLVED` |
| Imports | `IMPORT_TOO_LARGE`, `IMPORT_UNSUPPORTED_FORMAT`, `IMPORT_EMPTY`, `IMPORT_LIMIT`, `IMPORT_CORRUPT` |
| Device | `ALARM_PERMISSION_MISSING`, `NOTIFICATIONS_DISABLED`, `FULL_SCREEN_DENIED`, `BATTERY_OPTIMISED`, `STORAGE_FULL`, `AUDIO_UNAVAILABLE`, `CAMERA_PERMISSION_DENIED`, `CAMERA_UNAVAILABLE` |
| Local data | `LOCAL_DB_CORRUPT`, `LOCAL_DB_MIGRATION_FAILED`, `DATA_MALFORMED` |
| Billing / Plus | `PURCHASE_CANCELLED`, `PURCHASE_FAILED`, `PURCHASE_PENDING`, `PURCHASE_INVALID`, `BILLING_UNAVAILABLE`, `PLUS_REQUIRED`, `SAFF_OVER_LIMIT`, `SAFF_NOT_OVER_LIMIT` |

---

## 6. Retries

- **Who retries:** repositories only (and Firestore's own offline queue). ViewModels don't loop.
- **What:** only failures with `retryable: true` (network, `unavailable`, `aborted`, 5xx, timeouts).
- **Policy:** exponential backoff with full jitter: base 500 ms, factor 2, cap 30 s, max 4 attempts for
  user-initiated reads; 6 attempts for background sync. Background work beyond that waits for the
  next connectivity change or app open.
- **Writes:** must be idempotent before they may be retried:
  - Firestore writes to deterministic ids (`results/{uid}`, `selfies/{uid}`; votes are written by the
    `voteProposal` callable at `proposals/{id}/votes/{uid}`).
  - Callables carry a `requestId` (UUID v7, generated once per user action); the server stores
    processed ids for 24 h and returns the original response on repeats.
- **Riverpod:** global retry configured to defer to this policy (`ARCHITECTURE.md` §5).
- **Server:** task-queue functions use the platform retry config (max 5 attempts, backoff 10 s→5 min);
  handlers are idempotent (they check state before acting).

---

## 7. Showing errors to users

| Situation | Pattern |
|---|---|
| Screen can't load its data | `ErrorView`: message + Retry (if retryable) or the fix action |
| Action failed (button) | Inline error under the control, or a snackbar for transient failures |
| Device setting blocks a feature | `DeviceFixBanner` with a button that opens the exact setting |
| Background sync failing | Small offline banner; never a dialog |
| Wake flow | Never block the alarm or the game; degrade silently, show a one-line note at the reveal |

- `FailurePresenter` maps a failure to `(message, action?)` using `messageKey` and the failure's kind.
- Copy rules: say what happened and what to do; no apologies; no codes or exception text (a
  "Copy details" option in Settings → Feedback includes recent failure codes for support).
- Examples: `errorSkipTooLate` = "Skips need 8 hours' notice. This morning is too close."
  `errorNetworkOffline` = "You're offline. Your round is saved and will send when you reconnect."

---

## 8. Global handlers (bugs and the unexpected)

Installed in `bootstrap.dart` before `runApp`:
- `FlutterError.onError` → Crashlytics `recordFlutterFatalError` (release) / console (debug).
- `PlatformDispatcher.instance.onError` → Crashlytics fatal; return `true`.
- `Isolate.current.addErrorListener` for isolates we spawn (import parsing previews, content resolution).
- `ErrorWidget.builder` → a calm "Something broke on this screen" view with "Go back", in release.
- Riverpod `ProviderObserver` logs provider failures (with provider name) as non-fatals.
- The wake entrypoint has its own handlers; any uncaught error in the wake flow tells the native side
  to show the native fallback screen.

---

## 9. Logging

- `Log` interface in `saff_core` (`debug`, `info`, `warn`, `error(failure)`), implemented by:
  console (debug builds) and Crashlytics breadcrumbs + non-fatals (release).
- Structured: every entry has `event`, `area`, ids (`saffId`, `occurrenceId`, `requestId`), and failure code.
- **Never logged:** message text, answers, names, phone numbers, emails, tokens. A redaction step strips
  keys named in `redactedKeys` before anything leaves the device.
- Crashlytics custom keys: flavor, app version, saff size, Android version, OEM, battery-optimisation state.
- Non-fatal reporting: `UnknownFailure`, `DataFailure`, backend `internal`. Domain, network and device
  failures are counted, not reported individually.

---

## 10. Server side (TypeScript)

- `AppError` class mirrors the catalog: `new AppError('SKIP_TOO_LATE', {occurrenceId})`.
- Callables throw `HttpsError(catalog[code].httpsCode, message, { code, ...safeDetails })`; the client
  `FunctionsExceptionMapper` reads `details.code`.
- Input validation with `zod` schemas generated from `contracts/payloads`; invalid input →
  `INVALID_ARGUMENT` (bug in the client, reported).
- Unexpected errors: logged with `firebase-functions/logger` (structured, with `requestId`), returned as
  `SERVER_INTERNAL`; never leak stack traces to clients.
- Triggers and tasks: catch, log, and rethrow only when a retry can help (transient); otherwise record
  the failure on the affected document (e.g. `imports/{id}.status = failed, errorCode`) and finish.

---

## 11. Native alarm module (Kotlin)

- Pigeon host API methods return results or throw `FlutterError(code, message, details)` with codes from
  the catalog (`ALARM_PERMISSION_MISSING`, `FULL_SCREEN_DENIED`, ...), mapped by `PlatformExceptionMapper`.
- Inside the ring path, **no exception may stop the alarm**: every step (engine pre-warm, round lookup,
  vibration, custom sound) is wrapped; on failure it falls back (default alarm tone, native screen) and
  logs to a local ring log that the app uploads later as diagnostics.

---

## 12. Checklist for every new feature

- [ ] New failure codes added to `contracts/errors.json` and regenerated.
- [ ] Repository methods return `Result` and use `FailureMapper` with `context`.
- [ ] Every failure the screen can receive has a designed state (loading/empty/error/fix).
- [ ] Writes are idempotent before being retried.
- [ ] Tests: each failure path of the ViewModel; mapper coverage for new exception types.
- [ ] No personal data in logs.
