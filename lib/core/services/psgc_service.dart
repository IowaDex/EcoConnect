import 'dart:convert';

import 'package:http/http.dart' as http;

/// One entry from the Philippine Standard Geographic Code (PSGC) API.
class PsgcOption {
  const PsgcOption({required this.code, required this.name});

  final String code;
  final String name;

  @override
  bool operator ==(Object other) => other is PsgcOption && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => name;
}

/// Thrown when the PSGC API cannot be reached or returns an error.
class PsgcException implements Exception {
  const PsgcException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads provinces, cities/municipalities and barangays from the free PSGC
/// API (psgc.gitlab.io). Responses are cached per process, so moving back and
/// forth between fields never hits the network twice.
class PsgcService {
  PsgcService._();

  static final PsgcService instance = PsgcService._();

  static const _base = 'https://psgc.gitlab.io/api';

  /// Metro Manila is a region, not a province, but residents expect to find it
  /// in the province list.
  static const metroManilaCode = '130000000';

  static const _timeout = Duration(seconds: 20);

  final Map<String, Future<List<PsgcOption>>> _cache = {};

  Future<List<PsgcOption>> provinces() async {
    final list = await _load('/provinces.json');
    return [
      const PsgcOption(code: metroManilaCode, name: 'Metro Manila'),
      ...list,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<List<PsgcOption>> cities(String provinceCode) {
    if (provinceCode == metroManilaCode) {
      return _load('/regions/$provinceCode/cities-municipalities.json');
    }
    return _load('/provinces/$provinceCode/cities-municipalities.json');
  }

  Future<List<PsgcOption>> barangays(String cityCode) {
    return _load('/cities-municipalities/$cityCode/barangays.json');
  }

  Future<List<PsgcOption>> _load(String path) {
    final cached = _cache[path];
    if (cached != null) return cached;

    final request = _fetch(path).catchError((Object error) {
      _cache.remove(path);
      throw error;
    });
    _cache[path] = request;
    return request;
  }

  Future<List<PsgcOption>> _fetch(String path) async {
    final http.Response response;
    try {
      response = await http.get(Uri.parse('$_base$path')).timeout(_timeout);
    } catch (_) {
      throw const PsgcException(
        'Could not reach the location service. Check your connection.',
      );
    }

    if (response.statusCode != 200) {
      throw PsgcException('Location service error (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const PsgcException('Unexpected response from the location service');
    }

    final options = <PsgcOption>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final code = item['code'];
      final name = item['name'];
      if (code is String && name is String && name.isNotEmpty) {
        options.add(PsgcOption(code: code, name: name));
      }
    }
    options.sort((a, b) => a.name.compareTo(b.name));
    return options;
  }
}
