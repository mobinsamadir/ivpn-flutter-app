// lib/services/speed_test_service.dart

import 'dart:async';
import 'package:dio/dio.dart';

class SpeedTestService {
  final Dio _dio;

  // URL فایل تست را می‌توان به کانستراکتور منتقل کرد تا انعطاف‌پذیرتر باشد
  static const String _testFileUrl =
      'http://ipv4.download.thinkbroadband.com/5MB.zip';
  static const double _fileSizeInMegabits = 5.0 * 8; // 40 Mbit

  SpeedTestService({Dio? dio}) : _dio = dio ?? Dio();

  /// Tests the download speed and returns the result in Mbps.
  /// Returns 0.0 on failure.
  Future<double> testDownloadSpeed() async {
    final stopwatch = Stopwatch()..start();
    try {
      await _dio.get<List<int>>(
        _testFileUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      stopwatch.stop();

      final durationInSeconds = stopwatch.elapsed.inMilliseconds / 1000.0;
      if (durationInSeconds == 0) return 0.0;

      final speedMbps = _fileSizeInMegabits / durationInSeconds;
      return speedMbps;
    } catch (e) {
      print("Speed Test Failed: $e");
      return 0.0;
    }
  }
}
