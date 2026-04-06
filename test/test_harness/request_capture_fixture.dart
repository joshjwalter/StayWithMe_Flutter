import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class RequestCaptureFixture {
  Process? _process;
  late final StreamSubscription<String> _stdoutSubscription;
  final List<String> _stdoutLines = <String>[];

  late final String baseUrl;

  Future<void> start() async {
    final process = await Process.start(
      'python3',
      <String>['scripts/request_capture_server.py', '--host', '127.0.0.1', '--port', '0'],
      runInShell: false,
    );
    _process = process;

    final readyCompleter = Completer<String>();

    _stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          _stdoutLines.add(line);
          if (line.startsWith('SERVER_READY ') && !readyCompleter.isCompleted) {
            readyCompleter.complete(line.substring('SERVER_READY '.length));
          }
        });

    process.stderr.transform(utf8.decoder).listen((line) {
      _stdoutLines.add('STDERR: $line');
    });

    final readyLine = await readyCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw StateError('Server did not report readiness. Output: ${_stdoutLines.join(' | ')}'),
    );

    baseUrl = 'http://$readyLine';
    await _waitForHealthy();
  }

  Future<void> _waitForHealthy() async {
    final client = http.Client();
    try {
      final startedAt = DateTime.now();
      while (DateTime.now().difference(startedAt) < const Duration(seconds: 10)) {
        try {
          final response = await client.get(Uri.parse('$baseUrl/health'));
          if (response.statusCode == 200) {
            return;
          }
        } catch (_) {
          // Keep retrying until timeout.
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      client.close();
    }

    throw StateError('Server failed health check at $baseUrl');
  }

  Future<void> reset() async {
    final response = await http.post(Uri.parse('$baseUrl/__reset'));
    if (response.statusCode != 200) {
      throw StateError('Failed to reset capture server: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchEvents() async {
    final response = await http.get(Uri.parse('$baseUrl/requests'));
    if (response.statusCode != 200) {
      throw StateError('Failed to fetch captured requests: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final events = decoded['events'] as List<dynamic>? ?? <dynamic>[];
    return events.cast<Map<String, dynamic>>();
  }

  Future<void> stop() async {
    final process = _process;
    if (process == null) {
      return;
    }

    try {
      await http.post(Uri.parse('$baseUrl/__shutdown')).timeout(const Duration(seconds: 2));
    } catch (_) {
      process.kill(ProcessSignal.sigterm);
    }

    await process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
      process.kill(ProcessSignal.sigkill);
      return -1;
    });

    await _stdoutSubscription.cancel();
    _process = null;
  }
}
