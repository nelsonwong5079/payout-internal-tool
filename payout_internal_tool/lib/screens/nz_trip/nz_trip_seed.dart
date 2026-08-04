import 'nz_trip_models.dart';

/// Seed data for NZ trip (2 people / 14 days).
/// Pink-source items → Cat; yellow-highlighted → priority.
abstract final class NzTripSeed {
  static const tripId = 'shared';

  static const meColor = 0xFF1B7A6E; // forest teal
  static const catColor = 0xFFE07A5F; // warm coral

  static TripMeta meta() => TripMeta(
        title: 'NZ Trip · 14 days',
        seeded: true,
        departureDate: '2026-09-20',
        owners: const [
          TripOwner(id: 'me', label: 'Me', colorArgb: meColor),
          TripOwner(id: 'cat', label: 'Cat', colorArgb: catColor),
        ],
        categories: const [
          TripCategory(id: 'medicine', name: 'Medicine', order: 0),
          TripCategory(id: 'gear', name: 'Gear & Misc', order: 1),
          TripCategory(id: 'food', name: 'Food', order: 2),
          TripCategory(
            id: 'local',
            name: 'Local (buy in NZ)',
            order: 3,
            isLocal: true,
          ),
        ],
      );

  static List<TripItem> items() {
    TripItem i(
      String id,
      String name,
      String cat,
      String owner,
      String qty, {
      bool priority = false,
      bool local = false,
    }) =>
        TripItem(
          id: id,
          name: name,
          categoryId: cat,
          ownerId: owner,
          recommendedQty: qty,
          quantity: qty,
          priority: priority,
          buyLocation:
              local ? BuyLocation.inNz : BuyLocation.beforeDeparture,
        );

    return [
      // —— Medicine ——
      i('m01', '止泻药 (anti-diarrheal)', 'medicine', 'me', '1 strip (6–10 tabs)'),
      i('m02', 'Gastric (antacid)', 'medicine', 'me', '1 strip (~10)'),
      i('m03', 'Panadol', 'medicine', 'me', '1 box (10–20)'),
      i('m04', 'Flu (Morning)', 'medicine', 'cat', '1 strip (6–10)'),
      i('m05', 'Flu (Night)', 'medicine', 'cat', '1 strip (6–10)'),
      i('m06', 'Zytec (antihistamine)', 'medicine', 'me', '1 strip (~10)'),
      i('m07', '缓解疲劳 (fatigue relief)', 'medicine', 'me', '1 small pack'),
      i('m08', 'Dr Yen (Request Letter)', 'medicine', 'cat', '1 (document)'),
      i('m09', '风油 (medicated oil)', 'medicine', 'cat', '1 bottle'),
      i('m10', 'Sore throat', 'medicine', 'me', '1 pack'),
      i('m11', '金嗓子 (throat lozenge)', 'medicine', 'me', '1 pack'),
      i('m12', 'Vitamin C', 'medicine', 'me', '1 tube/bottle (~14–20)'),
      i('m13', 'Probiotic', 'medicine', 'me', '1 box (~14 sachets)'),
      i('m14', 'Flu GO', 'medicine', 'me', '1 box'),

      // —— Gear & Misc ——
      i('g01', '露营毯子/垫 (camping blanket/mat)', 'gear', 'me', '1–2'),
      i('g02', '电煲 (electric cooker)', 'gear', 'me', '1 (shared)',
          priority: true),
      i('g03', 'Tripod', 'gear', 'cat', '1'),
      i('g04', 'Car Phone Holder', 'gear', 'me', '1'),
      i('g05', '一次性床单 (disposable bed sheet)', 'gear', 'cat', '2–3'),
      i('g06', '一次性毛巾 (disposable towels)', 'gear', 'cat',
          '8–10 (≈1 / 3 days each)'),
      i('g07', '一次性餐具 (spoon/fork/bowl)', 'gear', 'cat', '1 pack (~20 sets)'),
      i('g08', '垃圾袋 (garbage bags)', 'gear', 'me', '1 roll (~15–20)'),
      i('g09', '抹脚布 (foot cloths)', 'gear', 'cat', '2'),
      i('g10', '洗碗 铁丝球 (steel wool)', 'gear', 'me', '1–2'),
      i('g11', '厨房铲 (spatula)', 'gear', 'me', '1'),
      i('g12', '洗碗精 固态 (solid dish soap)', 'gear', 'me', '1'),
      i('g13', 'Tissue (soft packs)', 'gear', 'cat',
          '4–6 total (with "Tissue x3")'),
      i('g14', '手机架 (phone stand)', 'gear', 'me', '1'),
      i('g15', '雨衣 (raincoats)', 'gear', 'cat', '2 (1 each)'),
      i('g16', '雨伞 (umbrella)', 'gear', 'me', '1–2'),
      i('g17', '口罩 (masks)', 'gear', 'cat', '1 box (10–20)'),
      i('g18', 'Sanitizer', 'gear', 'me', '1–2 (60–100ml)'),
      i('g19', 'Sanitizer Tissue (wet wipes)', 'gear', 'me', '1–2 packs'),
      i('g20', 'Lotion', 'gear', 'me', '1'),
      i('g21', '指甲剪 (nail clippers)', 'gear', 'me', '1'),
      i('g22', 'Shampoo', 'gear', 'me', '1 travel (100–200ml) or buy there',
          priority: true),
      i('g23', 'Cleanser', 'gear', 'me', '1 travel size', priority: true),
      i('g24', '眼药水 (eye drops)', 'gear', 'me', '1–2 bottles', priority: true),
      i('g25', '暖宫 (warming patches)', 'gear', 'cat', '1 pack (~5–10)'),

      // —— Food ——
      i('f01', 'Porridge (Sachet)', 'food', 'me', '7–10 sachets'),
      i('f02', 'Pedas Gila', 'food', 'me', '2–3'),
      i('f03', 'Shin Ramen', 'food', 'me', '4–6 packs'),
      i('f04', '酸辣粉 (hot & sour noodles)', 'food', 'me', '2–4'),
      i('f05', 'Candy (HIMALA)', 'food', 'me', '3'),
      i('f06', 'Paste (soup, seasoning)', 'food', 'me', '5–7 sachets'),
      i('f07', 'Black pepper', 'food', 'cat', '1 small bottle'),
      i('f08', '面条 / 米粉 (noodles / vermicelli)', 'food', 'cat', '4–6 servings'),

      // —— Local (buy in NZ) ——
      i('l01', '食油 (cooking oil)', 'local', 'me', '1 small bottle', local: true),
      i('l02', '面包 (bread)', 'local', 'me', '1 loaf at a time (perishable)',
          local: true),
      i('l03', 'Butter / Jam / Honey', 'local', 'me', '1 each (small)',
          local: true),
      i('l04', '老干妈 (chili crisp)', 'local', 'me', '1 jar', local: true),
      i('l05', '水 (water)', 'local', 'me',
          'as needed (NZ tap water is drinkable)',
          local: true),
    ];
  }
}
