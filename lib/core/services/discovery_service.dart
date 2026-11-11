import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smart discovery of VisaRecon local servers.
/// 1) Last known URL first
/// 2) Gateway + common hosts
/// 3) Parallel subnet scan, stop early
/// 4) Verify with HTTP /api/auth.status
class DiscoveryService {
  static const defaultPorts = [8642, 8643];
  static const _prefKey = 'last_server_url';

  static Future<List<DiscoveredServer>> scan({
    Duration timeout = const Duration(milliseconds: 280),
    void Function(int done, int total)? onProgress,
    bool stopOnFirst = true,
  }) async {
    final results = <DiscoveredServer>[];
    final seen = <String>{};

    void add(DiscoveredServer s) {
      if (seen.add(s.url)) results.add(s);
    }

    // 1) Last known
    final last = await _lastKnown();
    if (last != null) {
      onProgress?.call(1, 10);
      if (await _verify(last, timeout * 2)) {
        final uri = Uri.tryParse(last);
        if (uri != null && uri.host.isNotEmpty) {
          add(DiscoveredServer(host: uri.host, port: uri.port, url: last));
          if (stopOnFirst) {
            onProgress?.call(10, 10);
            return results;
          }
        }
      }
    }

    final myIps = await _localIPv4s();
    if (myIps.isEmpty) {
      onProgress?.call(10, 10);
      return results;
    }

    // 2) Priority hosts
    final priorityHosts = <String>{};
    for (final ip in myIps) {
      final parts = ip.split('.');
      if (parts.length != 4) continue;
      final p = '${parts[0]}.${parts[1]}.${parts[2]}';
      for (final o in [1, 2, 3, 4, 5, 10, 20, 50, 100, 150, 200, 254]) {
        priorityHosts.add('$p.$o');
      }
    }

    await _probeMany(
      priorityHosts.toList(),
      timeout: timeout,
      onHit: add,
      onProgress: (d, t) => onProgress?.call(d, t + 50),
      stopWhen: () => stopOnFirst && results.isNotEmpty,
    );

    if (results.isNotEmpty && stopOnFirst) {
      onProgress?.call(10, 10);
      await _saveLast(results.first.url);
      return results;
    }

    // 3) Rest of subnet
    final allHosts = <String>{};
    for (final ip in myIps) {
      final parts = ip.split('.');
      if (parts.length != 4) continue;
      final p = '${parts[0]}.${parts[1]}.${parts[2]}';
      for (var i = 1; i <= 254; i++) {
        final h = '$p.$i';
        if (!priorityHosts.contains(h)) allHosts.add(h);
      }
    }

    await _probeMany(
      allHosts.toList(),
      timeout: timeout,
      onHit: add,
      onProgress: (d, t) => onProgress?.call(5 + (d * 5 ~/ (t == 0 ? 1 : t)), 10),
      stopWhen: () => stopOnFirst && results.isNotEmpty,
      batchSize: 60,
    );

    results.sort((a, b) {
      if (a.port == 8642 && b.port != 8642) return -1;
      if (b.port == 8642 && a.port != 8642) return 1;
      return a.host.compareTo(b.host);
    });

    if (results.isNotEmpty) await _saveLast(results.first.url);
    onProgress?.call(10, 10);
    return results;
  }

  static Future<void> _probeMany(
    List<String> hosts, {
    required Duration timeout,
    required void Function(DiscoveredServer) onHit,
    void Function(int done, int total)? onProgress,
    bool Function()? stopWhen,
    int batchSize = 40,
  }) async {
    final total = hosts.length * defaultPorts.length;
    var done = 0;
    for (var i = 0; i < hosts.length; i += batchSize) {
      if (stopWhen?.call() == true) return;
      final batch = hosts.skip(i).take(batchSize);
      final futures = <Future>[];
      for (final host in batch) {
        for (final port in defaultPorts) {
          futures.add(() async {
            final open = await _tcpOpen(host, port, timeout);
            done++;
            onProgress?.call(done, total);
            if (!open) return;
            final url = 'http://$host:$port';
            if (await _verify(url, timeout * 2)) {
              onHit(DiscoveredServer(host: host, port: port, url: url));
            }
          }());
        }
      }
      await Future.wait(futures);
    }
  }

  static Future<bool> _tcpOpen(String host, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _verify(String baseUrl, Duration timeout) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth.status');
      final client = HttpClient()..connectionTimeout = timeout;
      final req = await client.postUrl(uri).timeout(timeout);
      req.headers.contentType = ContentType.json;
      req.write('{}');
      final res = await req.close().timeout(timeout);
      final body = await res.transform(const SystemEncoding().decoder).join();
      client.close(force: true);
      return res.statusCode == 200 &&
          (body.contains('needsSetup') || body.contains('ok') || body.contains('{'));
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> _localIPv4s() async {
    final out = <String>[];
    try {
      for (final iface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      )) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) out.add(addr.address);
        }
      }
    } catch (e) {
      if (kDebugMode) print('discovery ifaces: $e');
    }
    return out;
  }

  static Future<String?> _lastKnown() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefKey);
  }

  static Future<void> _saveLast(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefKey, url);
  }

  static Future<void> clearLast() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefKey);
  }
}

class DiscoveredServer {
  final String host;
  final int port;
  final String url;
  DiscoveredServer({required this.host, required this.port, required this.url});
}
