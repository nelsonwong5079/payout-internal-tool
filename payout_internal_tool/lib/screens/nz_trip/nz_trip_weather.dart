import 'dart:convert';

import 'package:http/http.dart' as http;

import 'nz_trip_models.dart';

enum WeatherSourceKind {
  /// Open-Meteo short-range (up to ~16 days) — most accurate day-by-day.
  forecast,

  /// ECMWF seasonal / sub-seasonal model — useful weeks–months ahead, less precise.
  seasonalOutlook,

  /// Historical climate normals — typical month, not a prediction for your dates.
  climateAverage,

  unavailable,
}

class DayWeather {
  const DayWeather({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.precipProb,
    required this.weatherCode,
    required this.summary,
  });

  final String date;
  final double tempMax;
  final double tempMin;
  final int precipProb;
  final int weatherCode;
  final String summary;
}

class LegWeather {
  const LegWeather({
    required this.leg,
    required this.source,
    required this.days,
    this.message,
    this.fetchedAt,
  });

  final WeatherLeg leg;
  final WeatherSourceKind source;
  final List<DayWeather> days;
  final String? message;
  final DateTime? fetchedAt;

  double? get avgHigh {
    if (days.isEmpty) return null;
    return days.map((d) => d.tempMax).reduce((a, b) => a + b) / days.length;
  }

  double? get avgLow {
    if (days.isEmpty) return null;
    return days.map((d) => d.tempMin).reduce((a, b) => a + b) / days.length;
  }

  int? get maxRainChance {
    if (days.isEmpty) return null;
    return days.map((d) => d.precipProb).reduce((a, b) => a > b ? a : b);
  }
}

class WeatherNudge {
  const WeatherNudge({
    required this.message,
    required this.emoji,
    this.matchedItemIds = const [],
    this.suggestedName,
  });

  final String message;
  final String emoji;
  final List<String> matchedItemIds;
  final String? suggestedName;
}

/// Open-Meteo live forecast + seasonal outlook + climate fallback (no API key).
class NzWeatherService {
  NzWeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const forecastHorizonDays = 16;
  static const seasonalHorizonDays = 180;

  Future<List<LegWeather>> fetchLegs(
    List<WeatherLeg> legs, {
    String? apiKey,
  }) async {
    // Fetch in parallel — many South Island stops.
    return Future.wait(legs.map(_fetchLeg));
  }

  Future<LegWeather> _fetchLeg(WeatherLeg leg) async {
    final start = DateTime.tryParse(leg.startDate);
    final end = DateTime.tryParse(leg.endDate);
    if (start == null || end == null) {
      return LegWeather(
        leg: leg,
        source: WeatherSourceKind.unavailable,
        days: const [],
        message: 'Invalid dates for ${leg.name}',
      );
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final forecastHorizon =
        todayDate.add(const Duration(days: forecastHorizonDays));
    final seasonalHorizon =
        todayDate.add(const Duration(days: seasonalHorizonDays));

    // Overlap with live forecast window → use short-range model.
    if (!start.isAfter(forecastHorizon)) {
      final live = await _fetchLiveForecast(leg, start, end, todayDate, forecastHorizon);
      if (live != null) return live;
    }

    // Further out → ECMWF seasonal outlook (still a model forecast).
    if (!start.isAfter(seasonalHorizon)) {
      final seasonal = await _fetchSeasonal(leg, start, end, todayDate);
      if (seasonal != null) return seasonal;
    }

    // Last resort: historical climate normals for packing guidance.
    return _fetchClimate(leg, start, end);
  }

  Future<LegWeather?> _fetchLiveForecast(
    WeatherLeg leg,
    DateTime start,
    DateTime end,
    DateTime todayDate,
    DateTime horizon,
  ) async {
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${leg.lat}',
        'longitude': '${leg.lon}',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
        'timezone': 'Pacific/Auckland',
        'forecast_days': '$forecastHorizonDays',
        'start_date': _clampDate(start, todayDate),
        'end_date': _iso(end.isAfter(horizon) ? horizon : end),
      });
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode >= 400) return null;
      final days = _parseDaily(jsonDecode(res.body) as Map<String, dynamic>);
      if (days.isEmpty) return null;

      String? message;
      if (end.isAfter(horizon)) {
        message =
            'Live day-by-day forecast for the next ~$forecastHorizonDays days. '
            'Later dates will use a seasonal outlook until closer to travel.';
      }
      return LegWeather(
        leg: leg,
        source: WeatherSourceKind.forecast,
        days: days,
        message: message,
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<LegWeather?> _fetchSeasonal(
    WeatherLeg leg,
    DateTime start,
    DateTime end,
    DateTime todayDate,
  ) async {
    try {
      final uri = Uri.https('seasonal-api.open-meteo.com', '/v1/seasonal', {
        'latitude': '${leg.lat}',
        'longitude': '${leg.lon}',
        'daily':
            'temperature_2m_max,temperature_2m_min,precipitation_sum,weather_code',
        'timezone': 'Pacific/Auckland',
        'start_date': _clampDate(start, todayDate),
        'end_date': _iso(end),
      });
      final res = await _client.get(uri).timeout(const Duration(seconds: 18));
      if (res.statusCode >= 400) return null;
      final days = _parseSeasonalDaily(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
      if (days.isEmpty) return null;
      return LegWeather(
        leg: leg,
        source: WeatherSourceKind.seasonalOutlook,
        days: days,
        message:
            'Seasonal outlook (ECMWF) for ${leg.name} — a model forecast for '
            'your dates, but not as precise as a live forecast. '
            'A detailed day-by-day forecast appears about $forecastHorizonDays days before.',
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<LegWeather> _fetchClimate(
    WeatherLeg leg,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final uri = Uri.https('climate-api.open-meteo.com', '/v1/climate', {
        'latitude': '${leg.lat}',
        'longitude': '${leg.lon}',
        'start_date': '1991-01-01',
        'end_date': '2020-12-31',
        'models': 'ERA5',
        'daily': 'temperature_2m_max,temperature_2m_min,precipitation_sum',
      });
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode >= 400) {
        return _seasonalFallback(leg, start);
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final daily = body['daily'] as Map<String, dynamic>?;
      if (daily == null) return _seasonalFallback(leg, start);

      final times = (daily['time'] as List?)?.cast<String>() ?? const [];
      final tmax = (daily['temperature_2m_max'] as List?) ?? const [];
      final tmin = (daily['temperature_2m_min'] as List?) ?? const [];
      final precip = (daily['precipitation_sum'] as List?) ?? const [];

      final month = start.month;
      var maxSum = 0.0, minSum = 0.0, precipSum = 0.0, n = 0;
      for (var i = 0; i < times.length; i++) {
        final d = DateTime.tryParse(times[i]);
        if (d == null || d.month != month) continue;
        final hi = (tmax[i] as num?)?.toDouble();
        final lo = (tmin[i] as num?)?.toDouble();
        final pr = (precip[i] as num?)?.toDouble() ?? 0;
        if (hi == null || lo == null) continue;
        maxSum += hi;
        minSum += lo;
        precipSum += pr;
        n++;
      }
      if (n == 0) return _seasonalFallback(leg, start);

      final avgMax = maxSum / n;
      final avgMin = minSum / n;
      final rainChance = (precipSum / n > 2.5) ? 55 : 30;

      return LegWeather(
        leg: leg,
        source: WeatherSourceKind.climateAverage,
        days: [
          DayWeather(
            date: leg.startDate,
            tempMax: avgMax,
            tempMin: avgMin,
            precipProb: rainChance,
            weatherCode: rainChance > 45 ? 61 : 1,
            summary: _wmoSummary(rainChance > 45 ? 61 : 1),
          ),
        ],
        message:
            'Typical ${_monthName(month)} weather for ${leg.name} '
            '(30-year average). This is not a prediction for your exact dates — '
            'use it for packing until a seasonal outlook or live forecast is available.',
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return _seasonalFallback(leg, start);
    }
  }

  LegWeather _seasonalFallback(WeatherLeg leg, DateTime start) {
    final month = start.month;
    final isSouth = leg.lat < -40;
    final avgMax = isSouth
        ? (month >= 9 && month <= 11 ? 15.0 : 18.0)
        : (month >= 9 && month <= 11 ? 18.0 : 22.0);
    final avgMin = avgMax - 8;
    return LegWeather(
      leg: leg,
      source: WeatherSourceKind.climateAverage,
      days: [
        DayWeather(
          date: leg.startDate,
          tempMax: avgMax,
          tempMin: avgMin,
          precipProb: 45,
          weatherCode: 3,
          summary: 'Changeable spring',
        ),
      ],
      message:
          'Typical ${_monthName(month)} weather for ${leg.name} '
          '(built-in average — weather API unavailable). '
          'Not a prediction for your exact travel dates.',
      fetchedAt: DateTime.now(),
    );
  }

  List<DayWeather> _parseDaily(Map<String, dynamic> body) {
    final daily = body['daily'] as Map<String, dynamic>?;
    if (daily == null) return const [];
    final times = (daily['time'] as List?)?.cast<String>() ?? const [];
    final tmax = (daily['temperature_2m_max'] as List?) ?? const [];
    final tmin = (daily['temperature_2m_min'] as List?) ?? const [];
    final precip =
        (daily['precipitation_probability_max'] as List?) ?? const [];
    final codes = (daily['weather_code'] as List?) ?? const [];
    final out = <DayWeather>[];
    for (var i = 0; i < times.length; i++) {
      final code = (codes.length > i ? (codes[i] as num?)?.toInt() : null) ?? 0;
      out.add(DayWeather(
        date: times[i],
        tempMax: (tmax.length > i ? (tmax[i] as num?)?.toDouble() : null) ?? 0,
        tempMin: (tmin.length > i ? (tmin[i] as num?)?.toDouble() : null) ?? 0,
        precipProb:
            (precip.length > i ? (precip[i] as num?)?.toInt() : null) ?? 0,
        weatherCode: code,
        summary: _wmoSummary(code),
      ));
    }
    return out;
  }

  /// Seasonal API returns ensemble mean in the base fields (no `_memberXX`).
  List<DayWeather> _parseSeasonalDaily(Map<String, dynamic> body) {
    final daily = body['daily'] as Map<String, dynamic>?;
    if (daily == null) return const [];
    final times = (daily['time'] as List?)?.cast<String>() ?? const [];
    final tmax = (daily['temperature_2m_max'] as List?) ?? const [];
    final tmin = (daily['temperature_2m_min'] as List?) ?? const [];
    final precip = (daily['precipitation_sum'] as List?) ?? const [];
    final codes = (daily['weather_code'] as List?) ?? const [];
    final out = <DayWeather>[];
    for (var i = 0; i < times.length; i++) {
      final code = (codes.length > i ? (codes[i] as num?)?.toInt() : null) ?? 0;
      final mm = (precip.length > i ? (precip[i] as num?)?.toDouble() : null) ?? 0;
      // Convert mm/day to a rough “chance of a wet day” for packing UI.
      final rainChance = mm <= 0.2
          ? 10
          : mm < 1
              ? 30
              : mm < 3
                  ? 50
                  : mm < 6
                      ? 65
                      : 80;
      out.add(DayWeather(
        date: times[i],
        tempMax: (tmax.length > i ? (tmax[i] as num?)?.toDouble() : null) ?? 0,
        tempMin: (tmin.length > i ? (tmin[i] as num?)?.toDouble() : null) ?? 0,
        precipProb: rainChance,
        weatherCode: code,
        summary: _wmoSummary(code),
      ));
    }
    return out;
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _clampDate(DateTime start, DateTime today) =>
      _iso(start.isBefore(today) ? today : start);

  static String _monthName(int m) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[m.clamp(1, 12)];
  }

  static String _wmoSummary(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Partly cloudy';
    if (code <= 48) return 'Foggy';
    if (code <= 57) return 'Drizzle';
    if (code <= 67) return 'Rain';
    if (code <= 77) return 'Snow';
    if (code <= 82) return 'Showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Mixed';
  }

  /// Build packing nudges from leg weather + existing items.
  static List<WeatherNudge> nudgesFor(
    List<LegWeather> legs,
    List<TripItem> items,
  ) {
    final out = <WeatherNudge>[];
    var cold = false;
    var rainy = false;
    var sunny = false;
    for (final leg in legs) {
      if (leg.source == WeatherSourceKind.unavailable) continue;
      final hi = leg.avgHigh ?? 20;
      final lo = leg.avgLow ?? 10;
      final rain = leg.maxRainChance ?? 0;
      if (lo < 8 || hi < 14) cold = true;
      if (rain >= 40) rainy = true;
      if (hi >= 18 && rain < 35) sunny = true;
    }

    String? findId(List<String> needles) {
      for (final i in items) {
        final n = i.name.toLowerCase();
        if (needles.any((x) => n.contains(x))) return i.id;
      }
      return null;
    }

    if (cold) {
      final id = findId(['thermal', 'warm layer', '暖', 'jacket', 'fleece']);
      out.add(WeatherNudge(
        emoji: '🧥',
        message: id != null
            ? 'Cool spell ahead — pack warm layers / thermals.'
            : 'Cool spell ahead — add warm layers / thermals to the list.',
        matchedItemIds: id != null ? [id] : const [],
        suggestedName: id == null ? 'Warm layers / thermals' : null,
      ));
    }
    if (rainy) {
      final coat = findId(['raincoat', '雨衣']);
      final umb = findId(['umbrella', '雨伞']);
      final ids = [if (coat != null) coat, if (umb != null) umb];
      out.add(WeatherNudge(
        emoji: '🌧️',
        message: ids.isNotEmpty
            ? 'Rain likely — keep raincoats + umbrella handy.'
            : 'Rain likely — add a raincoat / umbrella.',
        matchedItemIds: ids,
        suggestedName: ids.isEmpty ? '雨衣 (raincoats)' : null,
      ));
    }
    if (sunny) {
      final sun = findId(['sunscreen', 'spf']);
      final hat = findId(['hat', '帽']);
      final ids = [if (sun != null) sun, if (hat != null) hat];
      out.add(WeatherNudge(
        emoji: '☀️',
        message: ids.isNotEmpty
            ? 'Bright days — sunscreen + hat recommended.'
            : 'Bright days — add sunscreen / sun hat.',
        matchedItemIds: ids,
        suggestedName: ids.isEmpty ? 'Sunscreen' : null,
      ));
    }
    return out;
  }
}
