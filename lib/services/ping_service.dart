// lib/services/ping_service.dart

import 'dart:async';
import 'package:http/http.dart' as http;

class PingService {
  // برای تست‌پذیری بهتر، کلاینت http را از بیرون تزریق می‌کنیم
  final http.Client _client;
  static const int pingTimeout = 2500; // میلی‌ثانیه
  static const int failedPingValue = 9999; // یک عدد بزرگ برای پینگ ناموفق

  PingService({http.Client? client}) : _client = client ?? http.Client();

  /// Returns the latency to the server in milliseconds.
  /// Returns [failedPingValue] if the ping fails.
  Future<int> getPing(String ip, int port) async {
    final stopwatch = Stopwatch()..start();

    // ابتدا با https تست می‌کنیم
    try {
      final httpsUri = Uri.parse('https://[$ip]:$port');
      await _client
          .head(httpsUri)
          .timeout(const Duration(milliseconds: pingTimeout));
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      // اگر https ناموفق بود، با http تست می‌کنیم
      try {
        stopwatch.reset();
        final httpUri = Uri.parse('http://[$ip]:$port');
        await _client
            .head(httpUri)
            .timeout(const Duration(milliseconds: pingTimeout));
        stopwatch.stop();
        return stopwatch.elapsedMilliseconds;
      } catch (_) {
        // اگر هر دو ناموفق بودند
        return failedPingValue;
      }
    }
  }
}
