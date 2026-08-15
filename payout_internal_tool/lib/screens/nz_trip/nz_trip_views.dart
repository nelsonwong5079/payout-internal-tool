import 'package:flutter/material.dart';

import 'nz_trip_models.dart';
import 'nz_trip_theme.dart';
import 'nz_trip_weather.dart';
import 'nz_trip_widgets.dart';

/// Online / offline / pending-sync chip.
class NzConnectivityBar extends StatelessWidget {
  const NzConnectivityBar({
    super.key,
    required this.online,
    required this.pendingCount,
    this.lastSynced,
    this.onSync,
    this.syncing = false,
  });

  final bool online;
  final int pendingCount;
  final DateTime? lastSynced;
  final VoidCallback? onSync;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    final color = !online
        ? NzColors.goldDeep
        : pendingCount > 0
            ? NzColors.bought
            : NzColors.success;
    final label = !online
        ? 'Offline — changes saved on this phone'
        : pendingCount > 0
            ? '$pendingCount change${pendingCount == 1 ? '' : 's'} pending sync'
            : 'Online · synced';
    return Material(
      color: color.withValues(alpha: 0.14),
      child: InkWell(
        onTap: online && !syncing ? onSync : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(
                !online
                    ? Icons.cloud_off_rounded
                    : pendingCount > 0
                        ? Icons.sync_problem_rounded
                        : Icons.cloud_done_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: NzType.label.copyWith(fontSize: 11, color: color),
                ),
              ),
              if (syncing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NzColors.fern,
                  ),
                )
              else if (online && pendingCount > 0)
                Text(
                  'Sync',
                  style: NzType.label.copyWith(fontSize: 11, color: NzColors.fern),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Weather forecast / climate panel (filterable by location).
class NzWeatherPanel extends StatefulWidget {
  const NzWeatherPanel({
    super.key,
    required this.legs,
    required this.nudges,
    required this.loading,
    required this.onRefresh,
    required this.onManage,
    required this.onAddSuggested,
    required this.onOpenItem,
    this.lastFetchedAt,
    this.needsDailyRefresh = false,
    this.staleAt,
    this.error,
  });

  final List<LegWeather> legs;
  final List<WeatherNudge> nudges;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onManage;
  final ValueChanged<String> onAddSuggested;
  final ValueChanged<String> onOpenItem;
  final DateTime? lastFetchedAt;
  final bool needsDailyRefresh;
  final DateTime? staleAt;
  final String? error;

  @override
  State<NzWeatherPanel> createState() => _NzWeatherPanelState();
}

class _NzWeatherPanelState extends State<NzWeatherPanel> {
  final _locationSearch = TextEditingController();
  String _locationQuery = '';
  String? _selectedLegId; // null = all locations

  @override
  void dispose() {
    _locationSearch.dispose();
    super.dispose();
  }

  List<LegWeather> get _filteredLegs {
    var list = widget.legs;
    if (_selectedLegId != null) {
      list = list.where((l) => l.leg.id == _selectedLegId).toList();
    }
    final q = _locationQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((l) => l.leg.name.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  String _formatFetched(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLegs;
    final fetched = widget.lastFetchedAt ?? widget.staleAt;
    final freshToday = fetched != null && !widget.needsDailyRefresh;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NzColors.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NzColors.lake.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('🌤️ Weather', style: NzType.title.copyWith(fontSize: 14)),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh weather',
                visualDensity: VisualDensity.compact,
                onPressed: widget.loading ? null : widget.onRefresh,
                icon: widget.loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                color: NzColors.fern,
              ),
              TextButton(
                onPressed: widget.onManage,
                child: Text('Legs', style: NzType.label.copyWith(fontSize: 11)),
              ),
            ],
          ),
          _refreshInfoCard(fetched: fetched, freshToday: freshToday),
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 6),
              child: Text(widget.error!, style: NzType.body.copyWith(fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              'Trip window 29 Aug – 15 Sep 2026. '
              'Live forecast = next ~16 days. '
              'Seasonal outlook = model for later dates. '
              'Typical month = historical average only.',
              style: NzType.body.copyWith(fontSize: 11, color: NzColors.inkSoft),
            ),
          ),
          _locationFilterBar(),
          if (widget.legs.isEmpty && !widget.loading)
            Text(
              'Add destinations under Manage → Weather legs.',
              style: NzType.body.copyWith(fontSize: 12),
            )
          else if (filtered.isEmpty && !widget.loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No locations match this filter.',
                style: NzType.body.copyWith(fontSize: 12),
              ),
            )
          else
            ...filtered.map(_legCard),
          if (widget.nudges.isNotEmpty && _selectedLegId == null) ...[
            const SizedBox(height: 8),
            Text('Packing nudges', style: NzType.label.copyWith(fontSize: 11)),
            const SizedBox(height: 4),
            ...widget.nudges.map(_nudgeRow),
          ],
        ],
      ),
    );
  }

  Widget _refreshInfoCard({
    required DateTime? fetched,
    required bool freshToday,
  }) {
    final color = widget.loading
        ? NzColors.lake
        : freshToday
            ? NzColors.success
            : fetched == null
                ? NzColors.muted
                : NzColors.goldDeep;
    final title = widget.loading
        ? 'Refreshing weather…'
        : fetched == null
            ? 'Weather not loaded yet'
            : freshToday
                ? 'Showing today’s newest weather'
                : 'Weather may be outdated';
    final detail = widget.loading
        ? 'Pulling the latest forecast from the weather service.'
        : fetched == null
            ? 'Tap the refresh icon to fetch the latest forecast. '
                'After that, it auto-refreshes once per day.'
            : freshToday
                ? 'Last refreshed ${_formatFetched(fetched)}. '
                    'Auto-refreshes once a day; tap refresh anytime for the newest pull.'
                : 'Last refreshed ${_formatFetched(fetched)}. '
                    'A new daily update is due — tap refresh for the newest info.';

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            widget.loading
                ? Icons.sync_rounded
                : freshToday
                    ? Icons.verified_rounded
                    : Icons.info_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: NzType.title.copyWith(fontSize: 12.5, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: NzType.body.copyWith(fontSize: 11, color: NzColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationFilterBar() {
    final locations = widget.legs;
    if (locations.isEmpty) return const SizedBox.shrink();

    Widget chip(String? id, String label) {
      final on = _selectedLegId == id;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          selected: on,
          label: Text(
            label,
            style: NzType.label.copyWith(
              fontSize: 11,
              color: on ? NzColors.fern : NzColors.inkSoft,
            ),
          ),
          selectedColor: NzColors.fern.withValues(alpha: 0.18),
          checkmarkColor: NzColors.fern,
          backgroundColor: NzColors.snow,
          side: BorderSide(
            color: on
                ? NzColors.fern.withValues(alpha: 0.55)
                : NzColors.cardBorder,
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (_) => setState(() => _selectedLegId = id),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Filter location', style: NzType.label.copyWith(fontSize: 11)),
          const SizedBox(height: 6),
          TextField(
            controller: _locationSearch,
            onChanged: (v) => setState(() => _locationQuery = v),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search destinations…',
              hintStyle: NzType.body.copyWith(fontSize: 12, color: NzColors.muted),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
              suffixIcon: _locationQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        _locationSearch.clear();
                        setState(() => _locationQuery = '');
                      },
                    ),
              filled: true,
              fillColor: NzColors.snow,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: NzColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: NzColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: NzColors.fern.withValues(alpha: 0.7)),
              ),
            ),
            style: NzType.body.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip(null, 'All'),
                ...locations.map((l) => chip(l.leg.id, l.leg.name)),
              ],
            ),
          ),
          if (_selectedLegId != null || _locationQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Showing ${_filteredLegs.length} of ${locations.length} locations',
                style: NzType.label.copyWith(fontSize: 10, color: NzColors.muted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legCard(LegWeather leg) {
    final sourceLabel = switch (leg.source) {
      WeatherSourceKind.forecast => 'Live forecast',
      WeatherSourceKind.seasonalOutlook => 'Seasonal outlook',
      WeatherSourceKind.climateAverage => 'Typical for month',
      WeatherSourceKind.unavailable => 'Unavailable',
    };
    final sourceColor = switch (leg.source) {
      WeatherSourceKind.forecast => NzColors.success,
      WeatherSourceKind.seasonalOutlook => NzColors.lake,
      WeatherSourceKind.climateAverage => NzColors.goldDeep,
      WeatherSourceKind.unavailable => NzColors.muted,
    };
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: NzColors.snow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NzColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(leg.leg.name,
                    style: NzType.title.copyWith(fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: sourceColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  sourceLabel,
                  style: NzType.label.copyWith(fontSize: 9.5, color: sourceColor),
                ),
              ),
            ],
          ),
          Text(
            '${leg.leg.startDate} → ${leg.leg.endDate}',
            style: NzType.label.copyWith(fontSize: 10),
          ),
          if (leg.message != null) ...[
            const SizedBox(height: 4),
            Text(leg.message!, style: NzType.body.copyWith(fontSize: 11)),
          ],
          if (leg.days.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Avg high ${leg.avgHigh!.toStringAsFixed(0)}° · Avg low ${leg.avgLow!.toStringAsFixed(0)}° · Peak rain ${leg.maxRainChance}%',
              style: NzType.body.copyWith(fontSize: 12, color: NzColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Each day',
              style: NzType.label.copyWith(fontSize: 10.5),
            ),
            const SizedBox(height: 4),
            ...leg.days.map(_dayRow),
          ],
        ],
      ),
    );
  }

  Widget _dayRow(DayWeather d) {
    final dateLabel = d.date.length >= 10 ? d.date : d.date;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: NzColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NzColors.cardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              dateLabel,
              style: NzType.label.copyWith(fontSize: 11, color: NzColors.ink),
            ),
          ),
          Text(
            '${d.tempMax.toStringAsFixed(0)}° / ${d.tempMin.toStringAsFixed(0)}°',
            style: NzType.title.copyWith(fontSize: 12.5),
          ),
          const SizedBox(width: 8),
          Text(
            'Rain ${d.precipProb}%',
            style: NzType.label.copyWith(fontSize: 10.5, color: NzColors.lake),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              d.summary,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NzType.body.copyWith(fontSize: 11, color: NzColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nudgeRow(WeatherNudge n) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.message, style: NzType.body.copyWith(fontSize: 12)),
                if (n.matchedItemIds.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: n.matchedItemIds
                        .map(
                          (id) => TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => widget.onOpenItem(id),
                            child: Text(
                              'Open item',
                              style: NzType.label
                                  .copyWith(fontSize: 11, color: NzColors.fern),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                if (n.suggestedName != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => widget.onAddSuggested(n.suggestedName!),
                    child: Text(
                      'Add “${n.suggestedName}”',
                      style:
                          NzType.label.copyWith(fontSize: 11, color: NzColors.cat),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Group-by-bag packing view.
class NzBagView extends StatelessWidget {
  const NzBagView({
    super.key,
    required this.bags,
    required this.items,
    required this.ownerOf,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePacked,
    required this.onAssignBag,
    required this.onManageBags,
  });

  final List<TripBag> bags;
  final List<TripItem> items;
  final TripOwner? Function(String id) ownerOf;
  final ValueChanged<TripItem> onEdit;
  final ValueChanged<TripItem> onDelete;
  final Future<void> Function(TripItem, bool) onTogglePacked;
  final void Function(TripItem item, String bagId) onAssignBag;
  final VoidCallback onManageBags;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<TripItem>>{
      for (final b in bags) b.id: [],
      '': [],
    };
    for (final i in items.where((x) => !x.isLocal)) {
      final key = groups.containsKey(i.bagId) ? i.bagId : '';
      groups[key]!.add(i);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 72),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pack by bag — what’s in carry-on vs checked at the airport.',
                style: NzType.body.copyWith(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: onManageBags,
              child: Text('Bags', style: NzType.label.copyWith(fontSize: 11)),
            ),
          ],
        ),
        ...bags.map((b) => _bagSection(b, groups[b.id] ?? const [])),
        if ((groups[''] ?? const []).isNotEmpty)
          _bagSection(
            const TripBag(id: '', name: 'Unassigned', order: 99),
            groups['']!,
          ),
      ],
    );
  }

  Widget _bagSection(TripBag bag, List<TripItem> bagItems) {
    final packed = bagItems.where((i) => i.packed).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
          child: Row(
            children: [
              Text(
                bag.id == 'carry_on'
                    ? '🧳 ${bag.name}'
                    : bag.id == 'checked'
                        ? '📦 ${bag.name}'
                        : bag.id == 'personal'
                            ? '🎒 ${bag.name}'
                            : 'Tote ${bag.name}',
                style: NzType.title.copyWith(fontSize: 14),
              ),
              const Spacer(),
              Text(
                '$packed/${bagItems.length}',
                style: NzType.label,
              ),
            ],
          ),
        ),
        if (bag.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              bag.note,
              style: NzType.body.copyWith(fontSize: 11, color: NzColors.muted),
            ),
          ),
        if (bagItems.isEmpty)
          Text('No items yet', style: NzType.body.copyWith(fontSize: 12))
        else
          ...bagItems.map((item) => _bagRow(item)),
      ],
    );
  }

  Widget _bagRow(TripItem item) {
    final owner = ownerOf(item.ownerId);
    final flags = <String>[];
    if (item.isLiquidOver100ml) {
      flags.add(item.bagId == 'carry_on'
          ? '⚠️ >100ml — move to Checked'
          : '💧 >100ml → Checked');
    }
    if (item.isMedication && item.bagId == 'checked') {
      flags.add('💊 Meds better in Carry-on');
    } else if (item.isMedication) {
      flags.add('💊 Meds · keep on you');
    }
    if (item.isBiosecurity) flags.add('🌿 Declare at border');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: NzColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isLiquidOver100ml && item.bagId == 'carry_on'
              ? NzChrome.danger.withValues(alpha: 0.55)
              : NzColors.cardBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onEdit(item),
          onLongPress: () => onDelete(item),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: NzType.title.copyWith(
                          fontSize: 13.5,
                          decoration:
                              item.packed ? TextDecoration.lineThrough : null,
                          color: item.packed ? NzColors.muted : NzColors.ink,
                        ),
                      ),
                    ),
                    NzTickButton(
                      label: 'Packed',
                      value: item.packed,
                      onChanged: (v) => onTogglePacked(item, v),
                      color: NzColors.success,
                      reduceMotion: false,
                    ),
                  ],
                ),
                Text(
                  owner?.label ?? item.ownerId,
                  style: NzType.label.copyWith(fontSize: 10),
                ),
                if (flags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...flags.map(
                    (f) => Text(
                      f,
                      style: NzType.label.copyWith(
                        fontSize: 10.5,
                        color: f.startsWith('⚠️')
                            ? NzChrome.danger
                            : NzColors.inkSoft,
                      ),
                    ),
                  ),
                ],
                if (item.isLiquidOver100ml && item.bagId == 'carry_on')
                  TextButton(
                    onPressed: () => onAssignBag(item, 'checked'),
                    child: Text(
                      'Move to Checked',
                      style: NzType.label
                          .copyWith(fontSize: 11, color: NzColors.fern),
                    ),
                  ),
                if (item.isMedication && item.bagId == 'checked')
                  TextButton(
                    onPressed: () => onAssignBag(item, 'carry_on'),
                    child: Text(
                      'Move to Carry-on',
                      style: NzType.label
                          .copyWith(fontSize: 11, color: NzColors.fern),
                    ),
                  ),
                Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      tooltip: 'Edit',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 34, minHeight: 34),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: NzColors.fern,
                      onPressed: () => onEdit(item),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 34, minHeight: 34),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: NzChrome.danger,
                      onPressed: () => onDelete(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
