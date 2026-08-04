import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../firebase_options.dart';
import 'nz_trip_models.dart';
import 'nz_trip_seed.dart';

/// Shared NZ-trip backend via Firestore REST.
///
/// No polling — load once, then refresh only when the user asks
/// (or after a local mutation updates in-memory state).
class NzTripService {
  NzTripService({
    String tripId = NzTripSeed.tripId,
    http.Client? client,
  })  : _tripId = tripId,
        _client = client ?? http.Client();

  final String _tripId;
  final http.Client _client;

  static final String _projectId = DefaultFirebaseOptions.web.projectId;
  static final String _apiKey = DefaultFirebaseOptions.web.apiKey;
  static const _base = 'https://firestore.googleapis.com/v1/projects';

  String get _tripPath =>
      '$_base/$_projectId/databases/(default)/documents/nz_trip/$_tripId';
  String get _itemsPath => '$_tripPath/items';

  Uri _uri(String path, [Map<String, String>? query]) {
    final q = <String, String>{'key': _apiKey, ...?query};
    return Uri.parse(path).replace(queryParameters: q);
  }

  /// Uri with repeated updateMask.fieldPaths query params.
  Uri _uriWithMasks(String path, List<String> fieldPaths) {
    // Uri.replace collapses duplicate keys — build manually.
    final maskQs = fieldPaths
        .map((f) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(f)}')
        .join('&');
    return Uri.parse('$path?key=${Uri.encodeQueryComponent(_apiKey)}&$maskQs');
  }

  Future<TripMeta> fetchMeta() async {
    final res = await _client.get(_uri(_tripPath));
    if (res.statusCode == 404) return NzTripSeed.meta();
    if (res.statusCode >= 400) {
      throw Exception('Firestore meta ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final fields = (json['fields'] as Map<String, dynamic>?) ?? {};
    return TripMeta.fromMap(_decodeFields(fields));
  }

  Future<List<TripItem>> fetchItems() async {
    final res = await _client.get(_uri(_itemsPath, {'pageSize': '300'}));
    if (res.statusCode == 404) return const [];
    if (res.statusCode >= 400) {
      throw Exception('Firestore items ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = (json['documents'] as List?) ?? const [];
    final list = <TripItem>[];
    for (final d in docs) {
      if (d is! Map) continue;
      final name = d['name'] as String? ?? '';
      final id = name.split('/').last;
      final fields = (d['fields'] as Map<String, dynamic>?) ?? {};
      list.add(TripItem.fromMap(id, _decodeFields(fields)));
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Ensures trip meta + every seed item exists.
  /// Missing seed items are added; existing docs (ticks/edits) are left alone.
  Future<void> ensureSeeded() async {
    final res = await _client.get(_uri(_tripPath));
    if (res.statusCode != 200 && res.statusCode != 404) {
      throw Exception('Firestore seed check ${res.statusCode}: ${res.body}');
    }

    // Merge meta: keep user title/owners/categories if present; fill gaps.
    final seed = NzTripSeed.meta();
    TripMeta meta = seed;
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final fields = (json['fields'] as Map<String, dynamic>?) ?? {};
      final current = TripMeta.fromMap(_decodeFields(fields));
      meta = current.copyWith(
        seeded: true,
        departureDate: current.departureDate ?? seed.departureDate,
        owners: current.owners.isEmpty ? seed.owners : current.owners,
        categories:
            current.categories.isEmpty ? seed.categories : current.categories,
        title: current.title.trim().isEmpty ? seed.title : current.title,
      );
    }
    await _writeDoc(_tripPath, {
      ...meta.toMap(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });

    final existing = await fetchItems();
    final have = existing.map((e) => e.id).toSet();
    for (final item in NzTripSeed.items()) {
      if (have.contains(item.id)) continue;
      await _writeDoc('$_itemsPath/${item.id}', {
        ...item.toMap(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  Future<void> updateMeta(TripMeta meta) async {
    await _writeDoc(_tripPath, {
      ...meta.toMap(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> upsertItem(TripItem item) async {
    final effective =
        item.packed && !item.bought ? item.copyWith(bought: true) : item;
    await _writeDoc('$_itemsPath/${effective.id}', {
      ...effective.toMap(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Partial update — no GET required (uses updateMask).
  Future<void> patchItem(String id, Map<String, dynamic> fields) async {
    final patch = Map<String, dynamic>.from(fields);
    if (patch['packed'] == true) patch['bought'] = true;
    patch['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    final keys = patch.keys.toList();
    final body = jsonEncode({'fields': _encodeFields(patch)});
    final res = await _client.patch(
      _uriWithMasks('$_itemsPath/$id', keys),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (res.statusCode >= 400) {
      throw Exception('Patch failed ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> deleteItem(String id) async {
    final res = await _client.delete(_uri('$_itemsPath/$id'));
    if (res.statusCode >= 400 && res.statusCode != 404) {
      throw Exception('Delete failed ${res.statusCode}: ${res.body}');
    }
  }

  /// Encode a compressed image for Firestore (keeps under ~750KB payload).
  String encodeItemPhoto(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw Exception('Empty image');
    }
    if (bytes.lengthInBytes > 750000) {
      throw Exception(
        'Photo is too large after compression. Try a clearer close-up, or pick again.',
      );
    }
    return base64Encode(bytes);
  }

  String newItemId() =>
      'i_${DateTime.now().millisecondsSinceEpoch}_${_tripId.hashCode.abs()}';

  Future<void> _writeDoc(String path, Map<String, dynamic> data) async {
    final body = jsonEncode({'fields': _encodeFields(data)});
    final res = await _client.patch(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (res.statusCode >= 400) {
      throw Exception('Write failed ${res.statusCode}: ${res.body}');
    }
  }

  Map<String, dynamic> _decodeFields(Map<String, dynamic> fields) {
    final out = <String, dynamic>{};
    fields.forEach((k, v) {
      out[k] = _decodeValue(v);
    });
    return out;
  }

  dynamic _decodeValue(dynamic v) {
    if (v is! Map) return v;
    final m = Map<String, dynamic>.from(v);
    if (m.containsKey('stringValue')) return m['stringValue'];
    if (m.containsKey('booleanValue')) return m['booleanValue'] == true;
    if (m.containsKey('integerValue')) {
      return int.tryParse('${m['integerValue']}') ?? 0;
    }
    if (m.containsKey('doubleValue')) {
      return (m['doubleValue'] as num).toDouble();
    }
    if (m.containsKey('nullValue')) return null;
    if (m.containsKey('arrayValue')) {
      final values = (m['arrayValue'] as Map?)?['values'] as List? ?? const [];
      return values.map(_decodeValue).toList();
    }
    if (m.containsKey('mapValue')) {
      final f =
          (m['mapValue'] as Map?)?['fields'] as Map<String, dynamic>? ?? {};
      return _decodeFields(f);
    }
    return null;
  }

  Map<String, dynamic> _encodeFields(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((k, v) {
      out[k] = _encodeValue(v);
    });
    return out;
  }

  Map<String, dynamic> _encodeValue(dynamic v) {
    if (v == null) return {'nullValue': null};
    if (v is bool) return {'booleanValue': v};
    if (v is int) return {'integerValue': '$v'};
    if (v is double) return {'doubleValue': v};
    if (v is String) return {'stringValue': v};
    if (v is List) {
      return {
        'arrayValue': {'values': v.map(_encodeValue).toList()},
      };
    }
    if (v is Map) {
      return {
        'mapValue': {
          'fields': _encodeFields(Map<String, dynamic>.from(v)),
        },
      };
    }
    return {'stringValue': '$v'};
  }
}
