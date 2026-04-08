import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AlarmApiClient {
  AlarmApiClient({
    String? baseUrl,
    http.Client? client,
    DateTime Function()? nowProvider,
  }) : _baseUrl = _resolveBaseUrl(baseUrl),
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       _nowProvider = nowProvider ?? DateTime.now;

  final String _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _nowProvider;

  static String _resolveBaseUrl(String? explicitBaseUrl) {
    final fromArg = explicitBaseUrl?.trim() ?? '';
    if (fromArg.isNotEmpty) {
      return fromArg;
    }

    final fromEnv = const String.fromEnvironment('API_BASE_URL').trim();
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }

    if (kDebugMode && kIsWeb) {
      // Keep web debug runs easy by defaulting to the local capture server.
      return 'http://127.0.0.1:54010';
    }

    return '';
  }

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<AlarmRequestResult> sendStartAlarm({
    required Duration duration,
    required String timerId,
    bool stealthMode = false,
  }) async {
    if (!isConfigured) {
      return const AlarmRequestResult(
        sent: false,
        statusCode: null,
        responseBody: 'API_BASE_URL not configured',
      );
    }

    final uri = Uri.parse(_baseUrl).resolve('/alarm/start');
    final body = jsonEncode({
      'event': 'alarm_start',
      'requestedAt': _nowProvider().toUtc().toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'timerId': timerId,
      'stealthMode': stealthMode,
    });

    final response = await _client.post(
      uri,
      headers: const {'content-type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 5));

    return AlarmRequestResult(
      sent: true,
      statusCode: response.statusCode,
      responseBody: response.body,
    );
  }

  Future<AlarmRequestResult> sendCancelAlarm({
    required String timerId,
  }) async {
    if (!isConfigured) {
      return const AlarmRequestResult(
        sent: false,
        statusCode: null,
        responseBody: 'API_BASE_URL not configured',
      );
    }

    final uri = Uri.parse(_baseUrl).resolve('/alarm/cancel');
    final body = jsonEncode({
      'event': 'alarm_cancel',
      'requestedAt': _nowProvider().toUtc().toIso8601String(),
      'timerId': timerId,
    });

    final response = await _client.post(
      uri,
      headers: const {'content-type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 5));

    return AlarmRequestResult(
      sent: true,
      statusCode: response.statusCode,
      responseBody: response.body,
    );
  }

  /// Returns true when a GET /health to the configured server succeeds with
  /// a 2xx status code.  Returns false on any network failure or non-2xx
  /// response.
  Future<bool> checkConnectivity() async {
    if (!isConfigured) {
      return false;
    }
    try {
      final uri = Uri.parse(_baseUrl).resolve('/health');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 3));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

class AlarmRequestResult {
  const AlarmRequestResult({
    required this.sent,
    required this.statusCode,
    required this.responseBody,
  });

  final bool sent;
  final int? statusCode;
  final String responseBody;

  bool get isSuccess => sent && statusCode != null && statusCode! >= 200 && statusCode! < 300;
}
