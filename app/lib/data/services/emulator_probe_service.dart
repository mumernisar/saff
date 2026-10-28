import 'dart:io';

/// Checks whether a TCP port answers; used to tell the developer whether the
/// laptop's emulators are reachable from the phone.
// ignore: one_member_abstracts
abstract interface class EmulatorProbeService {
  /// Whether [host]:[port] accepts a connection within [timeout].
  Future<bool> isReachable(String host, int port, {Duration timeout});
}

/// Probes with a real socket.
final class SocketEmulatorProbeService implements EmulatorProbeService {
  /// Creates the service.
  const SocketEmulatorProbeService();

  @override
  Future<bool> isReachable(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    } on Exception {
      return false;
    }
  }
}
