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

    // Merge meta: keep user edits; fill missing bags / essentials / weather legs.
    final seed = NzTripSeed.meta();
    TripMeta meta = seed;
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final fields = (json['fields'] as Map<String, dynamic>?) ?? {};
      final current = TripMeta.fromMap(_decodeFields(fields));
      meta = _mergeMeta(current, seed);
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

  /// Merge seed defaults into an existing meta without wiping user data.
  TripMeta _mergeMeta(TripMeta current, TripMeta seed) {
    final cats = List<TripCategory>.from(
      current.categories.isEmpty ? seed.categories : current.categories,
    );
    for (final s in seed.categories) {
      if (!cats.any((c) => c.id == s.id)) cats.add(s);
    }
    cats.sort((a, b) => a.order.compareTo(b.order));

    final bags = List<TripBag>.from(
      current.bags.isEmpty ? seed.bags : current.bags,
    );
    for (final s in seed.bags) {
      if (!bags.any((b) => b.id == s.id)) bags.add(s);
    }
    bags.sort((a, b) => a.order.compareTo(b.order));

    // Upgrade from the old 2-leg default (Auckland + combined South Island)
    // to the full South Island destination list.
    final looksLikeOldDefault = current.weatherLegs.isEmpty ||
        (current.weatherLegs.length <= 2 &&
            current.weatherLegs.every(
              (l) => l.id == 'leg_akl' || l.id == 'leg_chc',
            ));
    final legs = looksLikeOldDefault
        ? List<WeatherLeg>.from(seed.weatherLegs)
        : List<WeatherLeg>.from(current.weatherLegs);
    if (!looksLikeOldDefault) {
      for (final s in seed.weatherLegs) {
        final i = legs.indexWhere((l) => l.id == s.id);
        if (i < 0) {
          legs.add(s);
        } else {
          // Keep shared trip weather window + official names/coords in sync.
          legs[i] = legs[i].copyWith(
            name: s.name,
            lat: s.lat,
            lon: s.lon,
            startDate: s.startDate,
            endDate: s.endDate,
          );
        }
      }
    }

    // Refresh departure when still on a previous seed default.
    final dep = current.departureDate;
    final departureDate = (dep == null ||
            dep.isEmpty ||
            dep == '2026-09-20' ||
            dep == '2026-09-24')
        ? seed.departureDate
        : dep;

    return current.copyWith(
      seeded: true,
      departureDate: departureDate,
      owners: current.owners.isEmpty ? seed.owners : current.owners,
      categories: cats,
      bags: bags,
      weatherLegs: legs,
      title: current.title.trim().isEmpty ? seed.title : current.title,
      weatherApiKey: current.weatherApiKey,
    );
  }

  /// Apply offline queue ops to the server (best-effort, in order).
  Future<void> flushQueue(List<Map<String, dynamic>> queue) async {
    for (final op in queue) {
      final type = op['type'] as String? ?? '';
      final id = op['id'] as String? ?? '';
      try {
        switch (type) {
          case 'upsert':
            final fields = Map<String, dynamic>.from(op['item'] as Map? ?? {});
            final item = TripItem.fromMap(id, fields);
            await upsertItem(item);
          case 'patch':
            final fields = Map<String, dynamic>.from(op['fields'] as Map? ?? {});
            if (fields.isEmpty || id.isEmpty) continue;
            await patchItem(id, fields);
          case 'delete':
            if (id.isEmpty) continue;
            await deleteItem(id);
          case 'meta':
            final fields = Map<String, dynamic>.from(op['meta'] as Map? ?? {});
            await updateMeta(TripMeta.fromMap(fields));
        }
      } catch (_) {
        // Leave remaining ops; caller can retry.
        rethrow;
      }
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
    // Goods: packed implies bought. Essentials use `ready` instead.
    if (patch['packed'] == true && patch['ready'] != true) {
      patch['bought'] = true;
    }
    // Normalize enums for wire format.
    if (patch['buyLocation'] is BuyLocation) {
      patch['buyLocation'] = (patch['buyLocation'] as BuyLocation).wire;
    }
    if (patch['kind'] is ItemKind) {
      patch['kind'] = (patch['kind'] as ItemKind).wire;
    }
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
