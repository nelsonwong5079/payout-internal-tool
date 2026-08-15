// Models for the NZ Trip prep & packing tracker.

enum BuyLocation {
  beforeDeparture,
  inNz;

  String get label => switch (this) {
        BuyLocation.beforeDeparture => 'Before departure',
        BuyLocation.inNz => 'In NZ (buy locally)',
      };

  String get wire => switch (this) {
        BuyLocation.beforeDeparture => 'before',
        BuyLocation.inNz => 'local',
      };

  static BuyLocation fromWire(String? v) =>
      v == 'local' ? BuyLocation.inNz : BuyLocation.beforeDeparture;
}

enum ItemStatus {
  pending,
  bought,
  packed,
  ready;

  String get label => switch (this) {
        ItemStatus.pending => 'Pending',
        ItemStatus.bought => 'Bought',
        ItemStatus.packed => 'Packed',
        ItemStatus.ready => 'Ready',
      };
}

/// Physical goods use bought+packed; essentials/docs use ready (+ optional packed).
enum ItemKind {
  goods,
  essential;

  String get wire => name;
  static ItemKind fromWire(String? v) =>
      v == 'essential' ? ItemKind.essential : ItemKind.goods;
}

class TripOwner {
  const TripOwner({
    required this.id,
    required this.label,
    required this.colorArgb,
  });

  final String id;
  final String label;
  final int colorArgb;

  TripOwner copyWith({String? id, String? label, int? colorArgb}) => TripOwner(
        id: id ?? this.id,
        label: label ?? this.label,
        colorArgb: colorArgb ?? this.colorArgb,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'colorArgb': colorArgb,
      };

  factory TripOwner.fromMap(Map<String, dynamic> m) => TripOwner(
        id: m['id'] as String? ?? '',
        label: m['label'] as String? ?? '',
        colorArgb: (m['colorArgb'] as num?)?.toInt() ?? 0xFF6366F1,
      );
}

class TripCategory {
  const TripCategory({
    required this.id,
    required this.name,
    required this.order,
    this.isLocal = false,
    this.isEssential = false,
  });

  final String id;
  final String name;
  final int order;
  final bool isLocal;
  final bool isEssential;

  TripCategory copyWith({
    String? id,
    String? name,
    int? order,
    bool? isLocal,
    bool? isEssential,
  }) =>
      TripCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        order: order ?? this.order,
        isLocal: isLocal ?? this.isLocal,
        isEssential: isEssential ?? this.isEssential,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'order': order,
        'isLocal': isLocal,
        'isEssential': isEssential,
      };

  factory TripCategory.fromMap(Map<String, dynamic> m) => TripCategory(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        order: (m['order'] as num?)?.toInt() ?? 0,
        isLocal: m['isLocal'] as bool? ?? false,
        isEssential: m['isEssential'] as bool? ?? false,
      );
}

class TripBag {
  const TripBag({
    required this.id,
    required this.name,
    required this.order,
    this.note = '',
  });

  final String id;
  final String name;
  final int order;
  /// Airline allowance notes, e.g. "7kg / 115cm".
  final String note;

  TripBag copyWith({
    String? id,
    String? name,
    int? order,
    String? note,
  }) =>
      TripBag(
        id: id ?? this.id,
        name: name ?? this.name,
        order: order ?? this.order,
        note: note ?? this.note,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'order': order,
        'note': note,
      };

  factory TripBag.fromMap(Map<String, dynamic> m) => TripBag(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        order: (m['order'] as num?)?.toInt() ?? 0,
        note: m['note'] as String? ?? '',
      );
}

class WeatherLeg {
  const WeatherLeg({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.startDate,
    required this.endDate,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final String startDate; // YYYY-MM-DD
  final String endDate;

  WeatherLeg copyWith({
    String? id,
    String? name,
    double? lat,
    double? lon,
    String? startDate,
    String? endDate,
  }) =>
      WeatherLeg(
        id: id ?? this.id,
        name: name ?? this.name,
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lon': lon,
        'startDate': startDate,
        'endDate': endDate,
      };

  factory WeatherLeg.fromMap(Map<String, dynamic> m) => WeatherLeg(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lon: (m['lon'] as num?)?.toDouble() ?? 0,
        startDate: m['startDate'] as String? ?? '',
        endDate: m['endDate'] as String? ?? '',
      );
}

class TripItem {
  const TripItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.ownerId,
    required this.recommendedQty,
    this.quantity = '',
    this.note = '',
    this.bought = false,
    this.packed = false,
    this.ready = false,
    this.priority = false,
    this.buyLocation = BuyLocation.beforeDeparture,
    this.photoBase64 = '',
    this.kind = ItemKind.goods,
    this.bagId = '',
    this.isLiquidOver100ml = false,
    this.isMedication = false,
    this.isBiosecurity = false,
    this.fieldTs = const {},
  });

  final String id;
  final String name;
  final String categoryId;
  final String ownerId;
  final String recommendedQty;
  final String quantity;
  final String note;
  final bool bought;
  final bool packed;
  /// Essentials/docs: "Ready / Got it" (not "bought").
  final bool ready;
  final bool priority;
  final BuyLocation buyLocation;
  final String photoBase64;
  final ItemKind kind;
  final String bagId;
  final bool isLiquidOver100ml;
  final bool isMedication;
  final bool isBiosecurity;
  /// Per-field last-write-wins timestamps (epoch ms).
  final Map<String, int> fieldTs;

  bool get isEssential => kind == ItemKind.essential;

  ItemStatus get status {
    if (isEssential) {
      if (packed) return ItemStatus.packed;
      if (ready) return ItemStatus.ready;
      return ItemStatus.pending;
    }
    if (packed) return ItemStatus.packed;
    if (bought) return ItemStatus.bought;
    return ItemStatus.pending;
  }

  bool get isLocal => buyLocation == BuyLocation.inNz;
  bool get hasPhoto => photoBase64.trim().isNotEmpty;
  bool get hasBag => bagId.trim().isNotEmpty;

  /// Essentials count as "done" for progress when ready (got it).
  bool get isPrepComplete =>
      isEssential ? (ready || packed) : packed;

  TripItem copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? ownerId,
    String? recommendedQty,
    String? quantity,
    String? note,
    bool? bought,
    bool? packed,
    bool? ready,
    bool? priority,
    BuyLocation? buyLocation,
    String? photoBase64,
    ItemKind? kind,
    String? bagId,
    bool? isLiquidOver100ml,
    bool? isMedication,
    bool? isBiosecurity,
    Map<String, int>? fieldTs,
  }) =>
      TripItem(
        id: id ?? this.id,
        name: name ?? this.name,
        categoryId: categoryId ?? this.categoryId,
        ownerId: ownerId ?? this.ownerId,
        recommendedQty: recommendedQty ?? this.recommendedQty,
        quantity: quantity ?? this.quantity,
        note: note ?? this.note,
        bought: bought ?? this.bought,
        packed: packed ?? this.packed,
        ready: ready ?? this.ready,
        priority: priority ?? this.priority,
        buyLocation: buyLocation ?? this.buyLocation,
        photoBase64: photoBase64 ?? this.photoBase64,
        kind: kind ?? this.kind,
        bagId: bagId ?? this.bagId,
        isLiquidOver100ml: isLiquidOver100ml ?? this.isLiquidOver100ml,
        isMedication: isMedication ?? this.isMedication,
        isBiosecurity: isBiosecurity ?? this.isBiosecurity,
        fieldTs: fieldTs ?? this.fieldTs,
      );

  /// Apply field patches with fresh LWW timestamps.
  TripItem applyFields(Map<String, dynamic> fields, {int? atMs}) {
    final at = atMs ?? DateTime.now().millisecondsSinceEpoch;
    final ts = Map<String, int>.from(fieldTs);
    var next = this;
    fields.forEach((k, v) {
      ts[k] = at;
      switch (k) {
        case 'name':
          next = next.copyWith(name: '$v');
        case 'categoryId':
          next = next.copyWith(categoryId: '$v');
        case 'ownerId':
          next = next.copyWith(ownerId: '$v');
        case 'recommendedQty':
          next = next.copyWith(recommendedQty: '$v');
        case 'quantity':
          next = next.copyWith(quantity: '$v');
        case 'note':
          next = next.copyWith(note: '$v');
        case 'bought':
          next = next.copyWith(bought: v == true);
        case 'packed':
          next = next.copyWith(packed: v == true);
        case 'ready':
          next = next.copyWith(ready: v == true);
        case 'priority':
          next = next.copyWith(priority: v == true);
        case 'buyLocation':
          next = next.copyWith(
            buyLocation: v is BuyLocation
                ? v
                : BuyLocation.fromWire(v as String?),
          );
        case 'photoBase64':
          next = next.copyWith(photoBase64: '$v');
        case 'kind':
          next = next.copyWith(
            kind: v is ItemKind ? v : ItemKind.fromWire(v as String?),
          );
        case 'bagId':
          next = next.copyWith(bagId: '$v');
        case 'isLiquidOver100ml':
          next = next.copyWith(isLiquidOver100ml: v == true);
        case 'isMedication':
          next = next.copyWith(isMedication: v == true);
        case 'isBiosecurity':
          next = next.copyWith(isBiosecurity: v == true);
      }
    });
    if (next.packed && !next.isEssential) {
      next = next.copyWith(bought: true);
      ts['bought'] = at;
    }
    return next.copyWith(fieldTs: ts);
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'categoryId': categoryId,
        'ownerId': ownerId,
        'recommendedQty': recommendedQty,
        'quantity': quantity,
        'note': note,
        'bought': bought,
        'packed': packed,
        'ready': ready,
        'priority': priority,
        'buyLocation': buyLocation.wire,
        'photoBase64': photoBase64,
        'kind': kind.wire,
        'bagId': bagId,
        'isLiquidOver100ml': isLiquidOver100ml,
        'isMedication': isMedication,
        'isBiosecurity': isBiosecurity,
        'fieldTs': fieldTs,
      };

  factory TripItem.fromMap(String id, Map<String, dynamic> m) {
    final tsRaw = m['fieldTs'];
    final ts = <String, int>{};
    if (tsRaw is Map) {
      tsRaw.forEach((k, v) {
        if (v is num) ts['$k'] = v.toInt();
      });
    }
    final kind = ItemKind.fromWire(m['kind'] as String?);
    // Legacy essentials category without kind field.
    final cat = m['categoryId'] as String? ?? '';
    final effectiveKind =
        kind == ItemKind.goods && cat == 'essentials'
            ? ItemKind.essential
            : kind;
    return TripItem(
      id: id,
      name: m['name'] as String? ?? '',
      categoryId: cat,
      ownerId: m['ownerId'] as String? ?? 'me',
      recommendedQty: m['recommendedQty'] as String? ?? '',
      quantity: m['quantity'] as String? ?? '',
      note: m['note'] as String? ?? '',
      bought: m['bought'] as bool? ?? false,
      packed: m['packed'] as bool? ?? false,
      ready: m['ready'] as bool? ?? false,
      priority: m['priority'] as bool? ?? false,
      buyLocation: BuyLocation.fromWire(m['buyLocation'] as String?),
      photoBase64: m['photoBase64'] as String? ?? '',
      kind: effectiveKind,
      bagId: m['bagId'] as String? ?? '',
      isLiquidOver100ml: m['isLiquidOver100ml'] as bool? ?? false,
      isMedication: m['isMedication'] as bool? ??
          (cat == 'medicine' && effectiveKind == ItemKind.goods),
      isBiosecurity: m['isBiosecurity'] as bool? ?? false,
      fieldTs: ts,
    );
  }

  /// Merge two versions field-by-field (last-write-wins).
  static TripItem mergeLww(TripItem a, TripItem b) {
    TripItem base = a;
    final keys = {
      'name',
      'categoryId',
      'ownerId',
      'recommendedQty',
      'quantity',
      'note',
      'bought',
      'packed',
      'ready',
      'priority',
      'buyLocation',
      'photoBase64',
      'kind',
      'bagId',
      'isLiquidOver100ml',
      'isMedication',
      'isBiosecurity',
    };
    for (final k in keys) {
      final ta = a.fieldTs[k] ?? 0;
      final tb = b.fieldTs[k] ?? 0;
      if (tb > ta) {
        base = base.applyFields({k: _fieldValue(b, k)}, atMs: tb);
      }
    }
    return base;
  }

  static dynamic _fieldValue(TripItem i, String k) => switch (k) {
        'name' => i.name,
        'categoryId' => i.categoryId,
        'ownerId' => i.ownerId,
        'recommendedQty' => i.recommendedQty,
        'quantity' => i.quantity,
        'note' => i.note,
        'bought' => i.bought,
        'packed' => i.packed,
        'ready' => i.ready,
        'priority' => i.priority,
        'buyLocation' => i.buyLocation,
        'photoBase64' => i.photoBase64,
        'kind' => i.kind,
        'bagId' => i.bagId,
        'isLiquidOver100ml' => i.isLiquidOver100ml,
        'isMedication' => i.isMedication,
        'isBiosecurity' => i.isBiosecurity,
        _ => null,
      };
}

class TripMeta {
  const TripMeta({
    required this.title,
    required this.owners,
    required this.categories,
    this.bags = const [],
    this.weatherLegs = const [],
    this.weatherApiKey = '',
    this.seeded = false,
    this.departureDate, // YYYY-MM-DD
    /// Item IDs intentionally removed — seed must not resurrect these.
    this.removedItemIds = const [],
  });

  final String title;
  final List<TripOwner> owners;
  final List<TripCategory> categories;
  final List<TripBag> bags;
  final List<WeatherLeg> weatherLegs;
  /// Optional OpenWeatherMap key; Open-Meteo is used when empty.
  final String weatherApiKey;
  final bool seeded;
  final String? departureDate;
  final List<String> removedItemIds;

  DateTime? get departureDateTime {
    final raw = departureDate;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  TripMeta copyWith({
    String? title,
    List<TripOwner>? owners,
    List<TripCategory>? categories,
    List<TripBag>? bags,
    List<WeatherLeg>? weatherLegs,
    String? weatherApiKey,
    bool? seeded,
    String? departureDate,
    List<String>? removedItemIds,
  }) =>
      TripMeta(
        title: title ?? this.title,
        owners: owners ?? this.owners,
        categories: categories ?? this.categories,
        bags: bags ?? this.bags,
        weatherLegs: weatherLegs ?? this.weatherLegs,
        weatherApiKey: weatherApiKey ?? this.weatherApiKey,
        seeded: seeded ?? this.seeded,
        departureDate: departureDate ?? this.departureDate,
        removedItemIds: removedItemIds ?? this.removedItemIds,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'owners': owners.map((o) => o.toMap()).toList(),
        'categories': categories.map((c) => c.toMap()).toList(),
        'bags': bags.map((b) => b.toMap()).toList(),
        'weatherLegs': weatherLegs.map((l) => l.toMap()).toList(),
        'weatherApiKey': weatherApiKey,
        'seeded': seeded,
        if (departureDate != null) 'departureDate': departureDate,
        'removedItemIds': removedItemIds,
      };

  factory TripMeta.fromMap(Map<String, dynamic> m) {
    final ownersRaw = (m['owners'] as List?) ?? const [];
    final catsRaw = (m['categories'] as List?) ?? const [];
    final bagsRaw = (m['bags'] as List?) ?? const [];
    final legsRaw = (m['weatherLegs'] as List?) ?? const [];
    final removedRaw = (m['removedItemIds'] as List?) ?? const [];
    return TripMeta(
      title: m['title'] as String? ?? 'NZ Trip',
      owners: ownersRaw
          .whereType<Map>()
          .map((e) => TripOwner.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      categories: catsRaw
          .whereType<Map>()
          .map((e) => TripCategory.fromMap(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
      bags: bagsRaw
          .whereType<Map>()
          .map((e) => TripBag.fromMap(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
      weatherLegs: legsRaw
          .whereType<Map>()
          .map((e) => WeatherLeg.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      weatherApiKey: m['weatherApiKey'] as String? ?? '',
      seeded: m['seeded'] as bool? ?? false,
      departureDate: m['departureDate'] as String?,
      removedItemIds: removedRaw.map((e) => '$e').where((e) => e.isNotEmpty).toList(),
    );
  }
}

class ProgressStats {
  const ProgressStats({
    required this.preTripTotal,
    required this.preTripBought,
    required this.preTripPacked,
    required this.localTotal,
    required this.localBought,
    required this.localPacked,
    required this.essentialsTotal,
    required this.essentialsReady,
    required this.essentialsPacked,
    required this.weightedTotal,
    required this.weightedComplete,
    required this.byOwner,
    required this.byCategory,
  });

  final int preTripTotal;
  final int preTripBought;
  final int preTripPacked;
  final int localTotal;
  final int localBought;
  final int localPacked;
  final int essentialsTotal;
  final int essentialsReady;
  final int essentialsPacked;
  /// Critical-weighted units (essentials count 2×).
  final int weightedTotal;
  final int weightedComplete;
  final Map<String, ({int total, int bought, int packed})> byOwner;
  final Map<String, ({int total, int bought, int packed})> byCategory;

  double get packedPct =>
      weightedTotal == 0 ? 0 : weightedComplete / weightedTotal;
  double get boughtPct =>
      preTripTotal == 0 ? 0 : preTripBought / preTripTotal;
  double get localPct =>
      localTotal == 0 ? 0 : localPacked / localTotal;
  double get essentialsPct =>
      essentialsTotal == 0 ? 0 : essentialsReady / essentialsTotal;

  static ProgressStats fromItems(List<TripItem> items) {
    final pre = items.where((i) => !i.isLocal).toList();
    final local = items.where((i) => i.isLocal).toList();
    final essentials = pre.where((i) => i.isEssential).toList();
    final goods = pre.where((i) => !i.isEssential).toList();

    ({int total, int bought, int packed}) tally(Iterable<TripItem> list) {
      var total = 0, bought = 0, packed = 0;
      for (final i in list) {
        total++;
        if (i.isEssential) {
          if (i.ready || i.packed) bought++;
        } else {
          if (i.bought || i.packed) bought++;
        }
        if (i.packed) packed++;
      }
      return (total: total, bought: bought, packed: packed);
    }

    var wTotal = 0;
    var wDone = 0;
    for (final i in goods) {
      wTotal += 1;
      if (i.packed) wDone += 1;
    }
    for (final i in essentials) {
      wTotal += 2;
      if (i.ready || i.packed) wDone += 2;
    }

    final byOwner = <String, ({int total, int bought, int packed})>{};
    final byCategory = <String, ({int total, int bought, int packed})>{};
    for (final i in pre) {
      final boughtOk = i.isEssential
          ? (i.ready || i.packed)
          : (i.bought || i.packed);
      final o = byOwner[i.ownerId] ?? (total: 0, bought: 0, packed: 0);
      byOwner[i.ownerId] = (
        total: o.total + 1,
        bought: o.bought + (boughtOk ? 1 : 0),
        packed: o.packed + (i.packed ? 1 : 0),
      );
      final c = byCategory[i.categoryId] ?? (total: 0, bought: 0, packed: 0);
      byCategory[i.categoryId] = (
        total: c.total + 1,
        bought: c.bought + (boughtOk ? 1 : 0),
        packed: c.packed + (i.packed ? 1 : 0),
      );
    }

    final preT = tally(pre);
    final locT = tally(local);
    final essReady = essentials.where((i) => i.ready || i.packed).length;
    final essPacked = essentials.where((i) => i.packed).length;

    return ProgressStats(
      preTripTotal: preT.total,
      preTripBought: preT.bought,
      preTripPacked: preT.packed,
      localTotal: locT.total,
      localBought: locT.bought,
      localPacked: locT.packed,
      essentialsTotal: essentials.length,
      essentialsReady: essReady,
      essentialsPacked: essPacked,
      weightedTotal: wTotal,
      weightedComplete: wDone,
      byOwner: byOwner,
      byCategory: byCategory,
    );
  }
}
