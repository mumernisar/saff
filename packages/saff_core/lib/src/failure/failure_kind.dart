/// The families of failure (`docs/ERRORS.md` §2).
enum FailureKind {
  /// A business rule said no; the user changes something.
  domain,

  /// No connection, timeout, DNS or TLS problem.
  network,

  /// The backend answered with an error.
  backend,

  /// A device setting or permission blocks the action.
  device,

  /// Malformed or unsupported data.
  data,

  /// Anything no mapper recognised.
  unknown,
}

/// How serious a failure is, for reporting and presentation.
enum FailureSeverity {
  /// Expected and harmless; never reported.
  info,

  /// Worth knowing about; the user can usually fix it.
  warning,

  /// Something failed that should not have.
  error,

  /// The app cannot continue the current task safely.
  critical,
}
