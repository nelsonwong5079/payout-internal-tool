import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'nz_trip_models.dart';

/// Local cache + offline mutation queue (web localStorage).
class NzTripOfflineStore {
  NzTripOfflineStore({this.tripId = 'shared'});

  final String tripId;

  String get _cacheKey => 'nz_trip_cache_$tripId';
  String get _queueKey => 'nz_trip_queue_$tripId';
  String get _weatherKey => 'nz_trip_weather_$tripId';

  bool get isOnline {
    try {
      return html.window.navigator.onLine ?? true;
    } catch (_) {
      return true;
    }
  }

  Stream<bool> get onOnlineChange {
    final controller = StreamController<bool>.broadcast();
    void emit() => controller.add(isOnline);
    html.window.addEventListener('online', (_) => emit());
    html.window.addEventListener('offline', (_) => emit());
    return controller.stream;
  }

  void saveCache({
    required TripMeta meta,
    required List<TripItem> items,
  }) {
    final payload = jsonEncode({
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'meta': meta.toMap(),
      'items': [
        for (final i in items) {'id': i.id, ...i.toMap()},
      ],
    });
    html.window.localStorage[_cacheKey] = payload;
  }

  ({TripMeta meta, List<TripItem> items, DateTime? savedAt})? loadCache() {
    final raw = html.window.localStorage[_cacheKey];
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final meta = TripMeta.fromMap(
        Map<String, dynamic>.from(json['meta'] as Map? ?? {}),
      );
      final itemsRaw = (json['items'] as List?) ?? const [];
      final items = <TripItem>[];
      for (final d in itemsRaw) {
        if (d is! Map) continue;
        final m = Map<String, dynamic>.from(d);
        final id = m['id'] as String? ?? '';
        if (id.isEmpty) continue;
        items.add(TripItem.fromMap(id, m));
      }
      final savedAt = DateTime.tryParse(json['savedAt'] as String? ?? '');
      return (meta: meta, items: items, savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> loadQueue() {
    final raw = html.window.localStorage[_queueKey];
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List? ?? const [];
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void saveQueue(List<Map<String, dynamic>> queue) {
    html.window.localStorage[_queueKey] = jsonEncode(queue);
  }

  void enqueue(Map<String, dynamic> op) {
    final q = loadQueue()..add(op);
    saveQueue(q);
  }

  int get pendingCount => loadQueue().length;

  void saveWeatherCache(String json) {
    final now = DateTime.now();
    html.window.localStorage[_weatherKey] = jsonEncode({
      'savedAt': now.toUtc().toIso8601String(),
      'dayKey': _localDayKey(now),
      'payload': json,
    });
  }

  ({String payload, DateTime? savedAt, String? dayKey})? loadWeatherCache() {
    final raw = html.window.localStorage[_weatherKey];
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return (
        payload: m['payload'] as String? ?? '',
        savedAt: DateTime.tryParse(m['savedAt'] as String? ?? ''),
        dayKey: m['dayKey'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// True when there is no cache, or cache was saved on a previous local day.
  bool weatherNeedsDailyRefresh() {
    final cached = loadWeatherCache();
    if (cached == null || cached.payload.isEmpty) return true;
    final key = cached.dayKey ?? _localDayKey(cached.savedAt?.toLocal());
    return key != _localDayKey(DateTime.now());
  }

  static String _localDayKey(DateTime? d) {
    final t = d ?? DateTime.now();
    final local = d == null ? t : t;
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

/// Merge remote items with local, applying LWW per field.
List<TripItem> mergeItemLists(List<TripItem> local, List<TripItem> remote) {
  final byId = <String, TripItem>{
    for (final i in local) i.id: i,
  };
  for (final r in remote) {
    final l = byId[r.id];
    byId[r.id] = l == null ? r : TripItem.mergeLww(l, r);
  }
  // Keep local-only items (created offline) that aren't deleted remotely.
  return byId.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
