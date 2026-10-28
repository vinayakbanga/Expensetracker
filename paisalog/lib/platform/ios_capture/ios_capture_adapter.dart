/// iOS capture platform adapter stub.
///
/// STATUS: UNVERIFIED — this is a stub only.
/// The iOS Shortcuts + App Intents capture path must be tested on the actual
/// iPhone before this code can be relied upon. See 04_iPhone_SMS_Capture_POC.docx.
///
/// Decision D-005 (processing timing) and D-001 (iOS install) are open.
library;

/// Represents a single queued SMS payload from the iOS capture layer.
/// Raw SMS body is NOT stored here — only safe derived fields.
class QuevedSmsPayload {
  /// SHA-256 fingerprint of safe derived fields for deduplication.
  final String fingerprint;

  /// Sender ID (e.g. 'HDFC-BK'). No account numbers.
  final String? sender;

  /// When the message was received.
  final DateTime receivedAt;

  /// The raw SMS body. Retained only transiently for parsing.
  /// Must be deleted from queue after successful processing.
  final String body;

  const QuevedSmsPayload({
    required this.fingerprint,
    required this.body,
    required this.receivedAt,
    this.sender,
  });
}

/// Platform adapter interface for SMS capture.
/// Concrete implementations live in platform/ and are isolated from domain.
abstract class IosCaptureAdapter {
  /// Returns all unprocessed payloads from the local queue.
  /// On real iOS this reads from an App Group shared container.
  Future<List<QuevedSmsPayload>> drainQueue();

  /// Mark a payload as processed. Deletes the raw body from the queue.
  Future<void> markProcessed(String fingerprint);

  /// Mark a payload as failed so it can be retried or surfaced in the UI.
  Future<void> markFailed(String fingerprint, String reason);

  /// Whether the capture path has been verified on the device.
  /// Returns false until a successful POC run is recorded.
  bool get isCaptureVerified;
}

/// Stub implementation used on Windows dev machine and before POC.
/// Logs a warning; does nothing. Never used in production.
class StubIosCaptureAdapter implements IosCaptureAdapter {
  @override
  Future<List<QuevedSmsPayload>> drainQueue() async {
    // STUB: no real capture on Windows / before POC
    return [];
  }

  @override
  Future<void> markProcessed(String fingerprint) async {
    // STUB: no-op
  }

  @override
  Future<void> markFailed(String fingerprint, String reason) async {
    // STUB: no-op
  }

  @override
  bool get isCaptureVerified => false;
}

