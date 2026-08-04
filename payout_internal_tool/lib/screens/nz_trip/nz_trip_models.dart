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
  packed;

  String get label => switch (this) {
        ItemStatus.pending => 'Pending',
        ItemStatus.bought => 'Bought',
        ItemStatus.packed => 'Packed',
      };
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
  });

  final String id;
  final String name;
  final int order;
  final bool isLocal;

  TripCategory copyWith({
    String? id,
    String? name,
    int? order,
    bool? isLocal,
  }) =>
      TripCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        order: order ?? this.order,
        isLocal: isLocal ?? this.isLocal,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'order': order,
        'isLocal': isLocal,
      };

  factory TripCategory.fromMap(Map<String, dynamic> m) => TripCategory(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        order: (m['order'] as num?)?.toInt() ?? 0,
        isLocal: m['isLocal'] as bool? ?? false,
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
    this.priority = false,
    this.buyLocation = BuyLocation.beforeDeparture,
    this.photoBase64 = '',
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
  final bool priority;
  final BuyLocation buyLocation;
  /// Compressed JPEG/PNG as base64 (empty if none). Synced via Firestore.
  final String photoBase64;

  ItemStatus get status {
    if (packed) return ItemStatus.packed;
    if (bought) return ItemStatus.bought;
    return ItemStatus.pending;
  }

  bool get isLocal => buyLocation == BuyLocation.inNz;
  bool get hasPhoto => photoBase64.trim().isNotEmpty;

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
    bool? priority,
    BuyLocation? buyLocation,
    String? photoBase64,
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
        priority: priority ?? this.priority,
        buyLocation: buyLocation ?? this.buyLocation,
        photoBase64: photoBase64 ?? this.photoBase64,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'categoryId': categoryId,
        'ownerId': ownerId,
        'recommendedQty': recommendedQty,
        'quantity': quantity,
        'note': note,
        'bought': bought,
        'packed': packed,
        'priority': priority,
        'buyLocation': buyLocation.wire,
        'photoBase64': photoBase64,
      };

  factory TripItem.fromMap(String id, Map<String, dynamic> m) => TripItem(
        id: id,
        name: m['name'] as String? ?? '',
        categoryId: m['categoryId'] as String? ?? '',
        ownerId: m['ownerId'] as String? ?? 'me',
        recommendedQty: m['recommendedQty'] as String? ?? '',
        quantity: m['quantity'] as String? ?? '',
        note: m['note'] as String? ?? '',
        bought: m['bought'] as bool? ?? false,
        packed: m['packed'] as bool? ?? false,
        priority: m['priority'] as bool? ?? false,
        buyLocation: BuyLocation.fromWire(m['buyLocation'] as String?),
        photoBase64: m['photoBase64'] as String? ?? '',
      );
}

class TripMeta {
  const TripMeta({
    required this.title,
    required this.owners,
    required this.categories,
    this.seeded = false,
    this.departureDate, // YYYY-MM-DD
  });

  final String title;
  final List<TripOwner> owners;
  final List<TripCategory> categories;
  final bool seeded;
  final String? departureDate;

  DateTime? get departureDateTime {
    final raw = departureDate;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  TripMeta copyWith({
    String? title,
    List<TripOwner>? owners,
    List<TripCategory>? categories,
    bool? seeded,
    String? departureDate,
  }) =>
      TripMeta(
        title: title ?? this.title,
        owners: owners ?? this.owners,
        categories: categories ?? this.categories,
        seeded: seeded ?? this.seeded,
        departureDate: departureDate ?? this.departureDate,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'owners': owners.map((o) => o.toMap()).toList(),
        'categories': categories.map((c) => c.toMap()).toList(),
        'seeded': seeded,
        if (departureDate != null) 'departureDate': departureDate,
      };

  factory TripMeta.fromMap(Map<String, dynamic> m) {
    final ownersRaw = (m['owners'] as List?) ?? const [];
    final catsRaw = (m['categories'] as List?) ?? const [];
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
      seeded: m['seeded'] as bool? ?? false,
      departureDate: m['departureDate'] as String?,
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
    required this.byOwner,
    required this.byCategory,
  });

  final int preTripTotal;
  final int preTripBought;
  final int preTripPacked;
  final int localTotal;
  final int localBought;
  final int localPacked;
  final Map<String, ({int total, int bought, int packed})> byOwner;
  final Map<String, ({int total, int bought, int packed})> byCategory;

  double get packedPct =>
      preTripTotal == 0 ? 0 : preTripPacked / preTripTotal;
  double get boughtPct =>
      preTripTotal == 0 ? 0 : preTripBought / preTripTotal;
  double get localPct =>
      localTotal == 0 ? 0 : localPacked / localTotal;

  static ProgressStats fromItems(List<TripItem> items) {
    final pre = items.where((i) => !i.isLocal).toList();
    final local = items.where((i) => i.isLocal).toList();

    ({int total, int bought, int packed}) tally(Iterable<TripItem> list) {
      var total = 0, bought = 0, packed = 0;
      for (final i in list) {
        total++;
        if (i.bought || i.packed) bought++;
        if (i.packed) packed++;
      }
      return (total: total, bought: bought, packed: packed);
    }

    final byOwner = <String, ({int total, int bought, int packed})>{};
    final byCategory = <String, ({int total, int bought, int packed})>{};
    for (final i in pre) {
      final o = byOwner[i.ownerId] ?? (total: 0, bought: 0, packed: 0);
      byOwner[i.ownerId] = (
        total: o.total + 1,
        bought: o.bought + ((i.bought || i.packed) ? 1 : 0),
        packed: o.packed + (i.packed ? 1 : 0),
      );
      final c = byCategory[i.categoryId] ?? (total: 0, bought: 0, packed: 0);
      byCategory[i.categoryId] = (
        total: c.total + 1,
        bought: c.bought + ((i.bought || i.packed) ? 1 : 0),
        packed: c.packed + (i.packed ? 1 : 0),
      );
    }

    final preT = tally(pre);
    final locT = tally(local);
    return ProgressStats(
      preTripTotal: preT.total,
      preTripBought: preT.bought,
      preTripPacked: preT.packed,
      localTotal: locT.total,
      localBought: locT.bought,
      localPacked: locT.packed,
      byOwner: byOwner,
      byCategory: byCategory,
    );
  }
}
