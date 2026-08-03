import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'gemini_service.dart';

/// Reactive tracker for backend (cloud backup) reachability.
///
/// Every [MealSyncService] sync/fetch reports success or failure here; the
/// shell shows a dismissible banner while [backendUnreachable] is true, so a
/// dead backend is never a silent failure again. A successful round-trip
/// (or a manual Retry probe) clears the banner automatically.
class SyncStatusService extends ChangeNotifier {
  SyncStatusService._();
  static final SyncStatusService instance = SyncStatusService._();

  bool _backendUnreachable = false;
  bool _dismissed = false;
  String _lastDetail = '';

  /// True when the last sync attempt failed and the banner hasn't been
  /// dismissed for that failure.
  bool get backendUnreachable => _backendUnreachable && !_dismissed;

  /// Human-readable detail of the last failure (endpoint name, HTTP code).
  String get lastDetail => _lastDetail;

  /// Called by [MealSyncService] whenever a cloud request fails.
  ///
  /// Short-circuits when the banner is already up with the same detail — a
  /// bulk sync against a dead backend (e.g. 20 meals) would otherwise fire
  /// one full shell rebuild per failed item.
  void reportFailure([String detail = '']) {
    if (_backendUnreachable && !_dismissed && _lastDetail == detail) return;
    _backendUnreachable = true;
    _dismissed = false; // a NEW failure re-shows the banner
    _lastDetail = detail;
    notifyListeners();
  }

  /// Called by [MealSyncService] whenever a cloud request succeeds.
  void reportSuccess() {
    if (!_backendUnreachable && _lastDetail.isEmpty) return;
    _backendUnreachable = false;
    _lastDetail = '';
    notifyListeners();
  }

  /// User dismissed the banner — hide it until the next failure.
  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    notifyListeners();
  }

  /// Re-probe the backend (Retry button). The root route returns 200 'OK'
  /// when the app is live; Railway returns a 404 JSON when no deployment is
  /// running on the domain.
  Future<bool> probeBackend() async {
    try {
      final resp = await http
          .get(Uri.parse('${GeminiService.serverUrl}/'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        reportSuccess();
        return true;
      }
      reportFailure('Backend responded with HTTP ${resp.statusCode}');
      return false;
    } catch (_) {
      reportFailure('Cannot reach backup server');
      return false;
    }
  }
}
