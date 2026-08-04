import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nz_trip_models.dart';
import 'nz_trip_photo_pick.dart';
import 'nz_trip_service.dart';
import 'nz_trip_theme.dart';
import 'nz_trip_widgets.dart';

/// Public NZ trip packing tracker — adventure-themed, shared via Firestore.
class NzTripScreen extends StatefulWidget {
  const NzTripScreen({super.key});

  @override
  State<NzTripScreen> createState() => _NzTripScreenState();
}

enum _Tab { dashboard, all, me, cat, local }

class _NzTripScreenState extends State<NzTripScreen> {
  final _svc = NzTripService();
  final _searchCtrl = TextEditingController();

  TripMeta? _meta;
  List<TripItem> _items = const [];

  _Tab _tab = _Tab.all;
  String? _filterOwner; // null = all
  ItemStatus? _filterStatus;
  String? _filterCategory;
  String _search = '';
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  bool _seeding = false;
  double _lastPackedPct = 0;
  String? _milestoneMessage;
  String? _milestoneEmoji;
  bool _confetti = false;
  bool _showAllDone = false;
  String? _tickToast;
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  void _onProgressChanged(double nextPct) {
    final crossed = NzMilestones.crossed(_lastPackedPct, nextPct);
    if (crossed != null) {
      setState(() {
        _milestoneMessage = NzMilestones.celebrateMessage(crossed);
        _milestoneEmoji = NzMilestones.scenicEmoji(crossed);
        _confetti = true;
        if (crossed >= 1.0) _showAllDone = true;
      });
      Future<void>.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _confetti = false);
      });
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _milestoneMessage = null;
            _milestoneEmoji = null;
          });
        }
      });
    }
    _lastPackedPct = nextPct;
  }

  void _flashTick(String msg) {
    setState(() => _tickToast = msg);
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && _tickToast == msg) setState(() => _tickToast = null);
    });
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _seeding = true;
      await _svc.ensureSeeded();
      _seeding = false;
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _seeding = false;
      });
    }
  }

  Future<void> _reload() async {
    final meta = await _svc.fetchMeta();
    final items = await _svc.fetchItems();
    if (!mounted) return;
    final pct = ProgressStats.fromItems(items).packedPct;
    setState(() {
      _meta = meta;
      _items = items;
      _loading = false;
      _error = null;
      _lastPackedPct = pct;
      if (pct >= 1.0 && items.where((i) => !i.isLocal).isNotEmpty) {
        // Don't auto-popup on every refresh — only via tick milestones.
      }
    });
  }

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _replaceItem(TripItem updated) {
    final before = _stats.packedPct;
    setState(() {
      _items = [
        for (final i in _items)
          if (i.id == updated.id) updated else i,
      ];
    });
    _onProgressChanged(_stats.packedPct);
    // silence unused if before equals after for bought-only
    if (before == _stats.packedPct) {
      // no milestone
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  ProgressStats get _stats => ProgressStats.fromItems(_items);

  List<TripItem> get _filtered {
    Iterable<TripItem> list = _items;

    // A Category chip means "everything in that category" — including Local
    // items when that category is selected — so tab local/owner scoping is
    // skipped. Explicit Owner chip below can still narrow further.
    final categoryFilterActive = _filterCategory != null;
    switch (_tab) {
      case _Tab.dashboard:
        break;
      case _Tab.all:
        if (!categoryFilterActive) {
          list = list.where((i) => !i.isLocal);
        }
        break;
      case _Tab.me:
        list = list.where((i) =>
            (categoryFilterActive || !i.isLocal) &&
            (categoryFilterActive || i.ownerId == 'me'));
        break;
      case _Tab.cat:
        list = list.where((i) =>
            (categoryFilterActive || !i.isLocal) &&
            (categoryFilterActive || i.ownerId == 'cat'));
        break;
      case _Tab.local:
        if (!categoryFilterActive) {
          list = list.where((i) => i.isLocal);
        }
        break;
    }

    // Explicit Owner chip (independent of Me/Cat tabs).
    if (_filterOwner != null) {
      list = list.where((i) => i.ownerId == _filterOwner);
    }
    // Category = all items in that category (Me + Cat), not owner-scoped.
    if (_filterCategory != null) {
      list = list.where((i) => i.categoryId == _filterCategory);
    }
    if (_filterStatus != null) {
      list = list.where((i) => i.status == _filterStatus);
    }
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((i) =>
          i.name.toLowerCase().contains(q) ||
          i.note.toLowerCase().contains(q) ||
          i.recommendedQty.toLowerCase().contains(q));
    }
    return list.toList();
  }

  TripOwner? _owner(String id) {
    try {
      return _meta?.owners.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _setBought(TripItem item, bool v) async {
    HapticFeedback.selectionClick();
    final prev = item;
    final next = item.copyWith(bought: v, packed: v ? item.packed : false);
    _replaceItem(next);
    if (v) _flashTick(NzCopy.tickCheer(false));
    try {
      await _svc.patchItem(item.id, {
        'bought': v,
        if (!v) 'packed': false,
      });
    } catch (e) {
      _replaceItem(prev);
      if (!mounted) return;
      _toast('Could not save: $e');
    }
  }

  Future<void> _setPacked(TripItem item, bool v) async {
    HapticFeedback.mediumImpact();
    final prev = item;
    final next = item.copyWith(packed: v, bought: v ? true : item.bought);
    _replaceItem(next);
    if (v) _flashTick(NzCopy.tickCheer(true));
    try {
      await _svc.patchItem(item.id, {
        'packed': v,
        if (v) 'bought': true,
      });
    } catch (e) {
      _replaceItem(prev);
      if (!mounted) return;
      _toast('Could not save: $e');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: NzType.body.copyWith(color: Colors.white)),
        backgroundColor: NzColors.night,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _editDepartureDate() async {
    final initial = _meta?.departureDateTime ?? DateTime(2026, 9, 20);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
      helpText: 'When do you fly to NZ?',
      builder: (ctx, child) => Theme(
        data: NzChrome.of(ctx),
        child: child!,
      ),
    );
    if (picked == null || _meta == null) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    final next = _meta!.copyWith(departureDate: iso);
    setState(() => _meta = next);
    await _svc.updateMeta(next);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final scopeOwnerId = _tab == _Tab.me
        ? 'me'
        : _tab == _Tab.cat
            ? 'cat'
            : null;
    final scopePct = scopeOwnerId != null
        ? () {
            final o = stats.byOwner[scopeOwnerId];
            if (o == null || o.total == 0) return 0.0;
            return o.packed / o.total;
          }()
        : _tab == _Tab.local
            ? stats.localPct
            : stats.packedPct;

    final meLabel = _owner('me')?.label ?? 'Me';
    final catLabel = _owner('cat')?.label ?? 'Cat';
    final meStat = stats.byOwner['me'] ?? (total: 0, bought: 0, packed: 0);
    final catStat = stats.byOwner['cat'] ?? (total: 0, bought: 0, packed: 0);
    final mePct = meStat.total == 0 ? 0.0 : meStat.packed / meStat.total;
    final catPct = catStat.total == 0 ? 0.0 : catStat.packed / catStat.total;
    final remaining = stats.preTripTotal - stats.preTripPacked;
    final cheer = NzCopy.encouraging(
      packedPct: stats.packedPct,
      remaining: remaining,
      meLabel: meLabel,
      catLabel: catLabel,
      mePct: mePct,
      catPct: catPct,
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Theme(
      data: NzChrome.of(context),
      child: Scaffold(
      backgroundColor: NzColors.snow,
      floatingActionButton: _tab == _Tab.dashboard
          ? null
          : FloatingActionButton(
              onPressed: () => _openItemEditor(),
              backgroundColor: NzColors.fern,
              foregroundColor: Colors.white,
              mini: true,
              tooltip: 'Add item',
              child: const Icon(Icons.add_rounded),
            ),
      body: NzAdventureBackground(
        child: Stack(
          children: [
            SafeArea(
          child: Column(
            children: [
              _Header(
                title: _meta?.title ?? 'NZ Trip',
                refreshing: _refreshing,
                departureDate: _meta?.departureDateTime,
                onEditDate: _editDepartureDate,
                onBack: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed('/');
                  }
                },
                onRefresh: _onRefresh,
                onManage: _meta == null ? null : _openManageSheet,
              ),
              if (_milestoneMessage != null)
                NzMilestoneBanner(
                  message: _milestoneMessage!,
                  emoji: _milestoneEmoji ?? '✨',
                ),
              NzJourneyProgress(
                overallPct: stats.packedPct,
                scopePct: scopePct,
                scopeLabel: _tab == _Tab.me
                    ? meLabel
                    : _tab == _Tab.cat
                        ? catLabel
                        : _tab == _Tab.local
                            ? 'Local'
                            : 'Overall',
                boughtPct: stats.boughtPct,
                packedLabel:
                    '${stats.preTripPacked}/${stats.preTripTotal}',
                cheer: cheer,
                mePct: mePct,
                catPct: catPct,
                meLabel: meLabel,
                catLabel: catLabel,
                reduceMotion: reduceMotion,
              ),
              _TabBar(
                tab: _tab,
                onChanged: (t) => setState(() {
                  _tab = t;
                  if (t == _Tab.dashboard) _filtersOpen = false;
                }),
                meLabel: meLabel,
                catLabel: catLabel,
              ),
              if (_tab != _Tab.dashboard) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                  child: Row(
                    children: [
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          _filtersOpen
                              ? Icons.expand_less_rounded
                              : Icons.tune_rounded,
                          size: 16,
                          color: NzColors.fern,
                        ),
                        label: Text(
                          _filtersOpen ? 'Hide filters' : 'Filters',
                          style: NzType.label.copyWith(
                            fontSize: 11,
                            color: NzColors.fern,
                          ),
                        ),
                        onPressed: () =>
                            setState(() => _filtersOpen = !_filtersOpen),
                        side: BorderSide(
                          color: _filtersOpen ||
                                  _filterOwner != null ||
                                  _filterStatus != null ||
                                  _filterCategory != null ||
                                  _search.isNotEmpty
                              ? NzColors.fern.withValues(alpha: 0.55)
                              : NzColors.cardBorder,
                        ),
                        backgroundColor: _filtersOpen
                            ? NzColors.fern.withValues(alpha: 0.12)
                            : NzColors.card,
                      ),
                      if (_filterOwner != null ||
                          _filterStatus != null ||
                          _filterCategory != null ||
                          _search.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _search = '';
                              _filterOwner = null;
                              _filterStatus = null;
                              _filterCategory = null;
                            });
                          },
                          child: Text(
                            'Clear',
                            style: NzType.label.copyWith(
                              color: NzColors.cat,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_filtersOpen)
                  _FilterBar(
                    searchCtrl: _searchCtrl,
                    search: _search,
                    onSearch: (v) => setState(() => _search = v),
                    onClearSearch: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                    },
                    filterOwner: _filterOwner,
                    filterStatus: _filterStatus,
                    filterCategory: _filterCategory,
                    owners: _meta?.owners ?? const [],
                    categories: _meta?.categories ?? const [],
                    ownerLabel: (id) => _owner(id)?.label ?? id,
                    onOwner: (v) => setState(() => _filterOwner = v),
                    onStatus: (v) => setState(() => _filterStatus = v),
                    onCategory: (v) => setState(() => _filterCategory = v),
                  ),
              ],
              Expanded(child: _buildBody(stats)),
            ],
          ),
            ),
            NzConfettiBurst(active: _confetti, reduceMotion: reduceMotion),
            if (_tickToast != null)
              Positioned(
                left: 24,
                right: 24,
                bottom: 96,
                child: Material(
                  color: NzColors.fern,
                  borderRadius: BorderRadius.circular(14),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      _tickToast!,
                      textAlign: TextAlign.center,
                      style: NzType.title.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            NzAllDoneOverlay(
              visible: _showAllDone,
              onDismiss: () => setState(() => _showAllDone = false),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildBody(ProgressStats stats) {
    if (_loading || _seeding) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: NzColors.fern),
            const SizedBox(height: 12),
            Text('Packing the campervan…', style: NzType.body),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 40, color: NzChrome.danger),
              const SizedBox(height: 12),
              Text('Could not sync', style: NzType.title),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: NzType.body.copyWith(color: NzColors.muted),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: NzColors.fern),
                onPressed: _boot,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_tab == _Tab.dashboard) {
      return _Dashboard(
        stats: stats,
        meta: _meta!,
        items: _items,
        onOpenOwner: (id) => setState(() {
          _tab = id == 'cat' ? _Tab.cat : _Tab.me;
        }),
        onOpenLocal: () => setState(() => _tab = _Tab.local),
        onOpenItem: (item) => _openItemEditor(item: item),
        onPhoto: _onItemPhotoTap,
        photoBusyIds: _photoBusy,
      );
    }

    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🐑', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Nothing here yet', style: NzType.title),
              const SizedBox(height: 6),
              Text(
                'Try another filter — or add something for the road trip!',
                textAlign: TextAlign.center,
                style: NzType.body,
              ),
            ],
          ),
        ),
      );
    }

    final cats = (_meta?.categories ?? const <TripCategory>[])
        .where((c) {
          // Category chip should reveal that section even if the active tab
          // normally hides Local / pre-trip groups.
          if (_filterCategory != null) return c.id == _filterCategory;
          if (_tab == _Tab.local) return c.isLocal;
          if (_tab == _Tab.all || _tab == _Tab.me || _tab == _Tab.cat) {
            return !c.isLocal;
          }
          return true;
        })
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 72),
      itemCount: cats.length,
      itemBuilder: (context, idx) {
        final cat = cats[idx];
        final catItems =
            filtered.where((i) => i.categoryId == cat.id).toList();
        if (catItems.isEmpty) return const SizedBox.shrink();
        final packed =
            catItems.where((i) => i.packed).length;
        final done = packed == catItems.length;
        return _CategorySection(
          category: cat,
          items: catItems,
          done: done,
          packedCount: packed,
          ownerOf: _owner,
          onToggleBought: _setBought,
          onTogglePacked: _setPacked,
          onEdit: (item) => _openItemEditor(item: item),
          onDelete: _confirmDeleteItem,
          onPhoto: _onItemPhotoTap,
          photoBusyIds: _photoBusy,
        );
      },
    );
  }

  Future<void> _confirmDeleteItem(TripItem item) async {
    final ok = await showNzConfirmDialog(
      context: context,
      title: 'Delete item?',
      message: 'Remove “${item.name}”? This syncs to both phones.',
      confirmLabel: 'Delete',
      emoji: '🗑️',
    );
    if (!ok) return;
    await _deleteItem(item);
  }

  Future<void> _deleteItem(TripItem item) async {
    final prev = List<TripItem>.from(_items);
    setState(() => _items = _items.where((i) => i.id != item.id).toList());
    try {
      await _svc.deleteItem(item.id);
      _toast('Removed “${item.name}”');
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = prev);
      _toast('Could not delete: $e');
    }
  }

  final Set<String> _photoBusy = {};

  Future<void> _onItemPhotoTap(TripItem item) async {
    if (item.hasPhoto) {
      await showNzPhotoViewer(
        context: context,
        title: item.name,
        photoBase64: item.photoBase64,
        onReplace: () => _pickAndUploadPhoto(item),
        onRemove: () => _removeItemPhoto(item),
      );
      return;
    }
    await _pickAndUploadPhoto(item);
  }

  Future<void> _pickAndUploadPhoto(TripItem item) async {
    // IMPORTANT (iPhone Safari): the file/camera dialog must open in the same
    // user-gesture turn as the tap. Popping the sheet first then calling a
    // picker later is silently ignored — so we pick inside the tile onTap.
    final bytes = await showNzSheet<Uint8List>(
      context: context,
      builder: (ctx) => NzSheetShell(
        title: item.hasPhoto ? 'Replace photo' : 'Add purchase photo',
        emoji: '📸',
        subtitle: 'So both phones can see what you bought',
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.photo_camera_rounded, color: NzColors.fern),
              title:
                  Text('Take photo', style: NzType.title.copyWith(fontSize: 14)),
              onTap: () {
                // Keep picker open inside this tap turn (no await before click).
                pickImageBytesWeb(fromCamera: true).then((picked) {
                  if (ctx.mounted) Navigator.pop(ctx, picked);
                });
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_rounded,
                  color: NzColors.lake),
              title: Text('Choose from library',
                  style: NzType.title.copyWith(fontSize: 14)),
              onTap: () {
                pickImageBytesWeb(fromCamera: false).then((picked) {
                  if (ctx.mounted) Navigator.pop(ctx, picked);
                });
              },
            ),
          ],
        ),
      ),
    );
    if (bytes == null || !mounted) return;
    await _saveItemPhoto(item, bytes);
  }

  Future<void> _saveItemPhoto(TripItem item, Uint8List bytes) async {
    setState(() => _photoBusy.add(item.id));
    try {
      final encoded = _svc.encodeItemPhoto(bytes);
      final next = item.copyWith(photoBase64: encoded);
      _replaceItem(next);
      await _svc.patchItem(item.id, {'photoBase64': encoded});
      _toast('Photo saved for “${item.name}” 📸');
    } catch (e) {
      if (!mounted) return;
      _toast('Could not save photo: $e');
    } finally {
      if (mounted) setState(() => _photoBusy.remove(item.id));
    }
  }

  Future<void> _removeItemPhoto(TripItem item) async {
    if (!item.hasPhoto) return;
    final ok = await showNzConfirmDialog(
      context: context,
      title: 'Remove photo?',
      message: 'Delete the purchase photo for “${item.name}”?',
      confirmLabel: 'Remove',
      emoji: '📸',
    );
    if (!ok) return;
    setState(() => _photoBusy.add(item.id));
    final prev = item;
    final next = item.copyWith(photoBase64: '');
    _replaceItem(next);
    try {
      await _svc.patchItem(item.id, {'photoBase64': ''});
      _toast('Photo removed');
    } catch (e) {
      if (!mounted) return;
      _replaceItem(prev);
      _toast('Could not remove photo: $e');
    } finally {
      if (mounted) setState(() => _photoBusy.remove(item.id));
    }
  }

  Future<void> _openItemEditor({TripItem? item}) async {
    final meta = _meta;
    if (meta == null) return;
    final result = await showNzSheet<_ItemEditorOutcome>(
      context: context,
      builder: (ctx) => _ItemEditorSheet(
        meta: meta,
        initial: item,
        defaultOwnerId: _tab == _Tab.cat ? 'cat' : 'me',
        defaultLocal: _tab == _Tab.local,
      ),
    );
    if (result == null) return;
    if (result.delete) {
      if (item != null) await _deleteItem(item);
      return;
    }
    final draft = result.draft;
    if (draft == null) return;
    final id = item?.id ?? _svc.newItemId();
    final next = draft.toItem(id).copyWith(
          photoBase64: item?.photoBase64 ?? '',
        );
    if (item == null) {
      setState(() => _items = [..._items, next]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
      _toast('Added “${next.name}” 🎒');
    } else {
      _replaceItem(next);
      _toast('Saved “${next.name}”');
    }
    try {
      await _svc.upsertItem(next);
    } catch (e) {
      if (!mounted) return;
      _toast('Could not save: $e');
      await _onRefresh();
    }
  }

  Future<void> _openManageSheet() async {
    final meta = _meta;
    if (meta == null) return;
    await showNzSheet<void>(
      context: context,
      builder: (ctx) => _ManageSheet(
        meta: meta,
        onSaveMeta: (m) async {
          await _svc.updateMeta(m);
          if (mounted) setState(() => _meta = m);
        },
      ),
    );
  }
}

// ─── Header / sticky progress / tabs ───────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onBack,
    required this.onRefresh,
    required this.departureDate,
    required this.onEditDate,
    this.refreshing = false,
    this.onManage,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final DateTime? departureDate;
  final VoidCallback onEditDate;
  final bool refreshing;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            color: NzColors.inkSoft,
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NzType.display.copyWith(fontSize: 15),
            ),
          ),
          NzCountdownChip(
            departureDate: departureDate,
            onEditDate: onEditDate,
          ),
          IconButton(
            tooltip: 'Refresh',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: refreshing ? null : onRefresh,
            icon: refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: NzColors.fern,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 19),
            color: NzColors.fern,
          ),
          IconButton(
            tooltip: 'Manage',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: onManage,
            icon: const Icon(Icons.settings_rounded, size: 19),
            color: NzColors.inkSoft,
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tab,
    required this.onChanged,
    required this.meLabel,
    required this.catLabel,
  });

  final _Tab tab;
  final ValueChanged<_Tab> onChanged;
  final String meLabel;
  final String catLabel;

  @override
  Widget build(BuildContext context) {
    Widget chip(_Tab t, String label) {
      final on = tab == t;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: on ? NzColors.fern.withValues(alpha: 0.16) : NzColors.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => onChanged(t),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: on
                        ? NzColors.fern.withValues(alpha: 0.55)
                        : NzColors.cardBorder,
                  ),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NzType.label.copyWith(
                    fontSize: 10,
                    color: on ? NzColors.fern : NzColors.inkSoft,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      child: Row(
        children: [
          chip(_Tab.dashboard, 'Dash'),
          chip(_Tab.all, 'All'),
          chip(_Tab.me, meLabel),
          chip(_Tab.cat, catLabel),
          chip(_Tab.local, 'Local'),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchCtrl,
    required this.search,
    required this.onSearch,
    required this.onClearSearch,
    required this.filterOwner,
    required this.filterStatus,
    required this.filterCategory,
    required this.owners,
    required this.categories,
    required this.ownerLabel,
    required this.onOwner,
    required this.onStatus,
    required this.onCategory,
  });

  final TextEditingController searchCtrl;
  final String search;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final String? filterOwner;
  final ItemStatus? filterStatus;
  final String? filterCategory;
  final List<TripOwner> owners;
  final List<TripCategory> categories;
  final String Function(String id) ownerLabel;
  final ValueChanged<String?> onOwner;
  final ValueChanged<ItemStatus?> onStatus;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context) {
    String? catName;
    for (final c in categories) {
      if (c.id == filterCategory) {
        catName = c.name;
        break;
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
      child: Column(
        children: [
          TextField(
            controller: searchCtrl,
            onChanged: onSearch,
            style: NzType.body,
            decoration: NzChrome.input(
              'Search',
              hint: 'Search packing list…',
              suffix: search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: onClearSearch,
                    ),
            ).copyWith(
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 18,
                color: NzColors.fern,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  label: filterOwner == null
                      ? 'Owner: All'
                      : 'Owner: ${ownerLabel(filterOwner!)}',
                  onTap: () => _pickOwner(context),
                ),
                const SizedBox(width: 6),
                _filterChip(
                  label: filterStatus == null
                      ? 'Status: All'
                      : 'Status: ${filterStatus!.label}',
                  onTap: () => _pickStatus(context),
                ),
                const SizedBox(width: 6),
                _filterChip(
                  label: filterCategory == null
                      ? 'Category: All'
                      : 'Category: ${catName ?? ''}',
                  onTap: () => _pickCategory(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required VoidCallback onTap}) {
    return ActionChip(
      label: Text(label, style: NzType.label.copyWith(fontSize: 11)),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      side: const BorderSide(color: NzColors.cardBorder),
      backgroundColor: NzColors.card,
    );
  }

  Future<void> _pickOwner(BuildContext context) async {
    final picked = await showNzSheet<String?>(
      context: context,
      builder: (ctx) => NzSheetShell(
        title: 'Owner',
        emoji: '👥',
        child: Column(
          children: [
            _pickTile(ctx, 'All owners', ''),
            ...owners.map((o) => _pickTile(ctx, o.label, o.id)),
          ],
        ),
      ),
    );
    if (picked == null) return;
    onOwner(picked.isEmpty ? null : picked);
  }

  Future<void> _pickStatus(BuildContext context) async {
    final picked = await showNzSheet<String>(
      context: context,
      builder: (ctx) => NzSheetShell(
        title: 'Status',
        emoji: '📦',
        child: Column(
          children: [
            _pickTile(ctx, 'All statuses', ''),
            ...ItemStatus.values.map((s) => _pickTile(ctx, s.label, s.name)),
          ],
        ),
      ),
    );
    if (picked == null) return;
    onStatus(picked.isEmpty ? null : ItemStatus.values.byName(picked));
  }

  Future<void> _pickCategory(BuildContext context) async {
    final picked = await showNzSheet<String?>(
      context: context,
      builder: (ctx) => NzSheetShell(
        title: 'Category',
        emoji: '🗂️',
        child: Column(
          children: [
            _pickTile(ctx, 'All categories', ''),
            ...categories.map((c) => _pickTile(ctx, c.name, c.id)),
          ],
        ),
      ),
    );
    if (picked == null) return;
    onCategory(picked.isEmpty ? null : picked);
  }

  Widget _pickTile(BuildContext ctx, String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: NzType.title.copyWith(fontSize: 14)),
      onTap: () => Navigator.pop(ctx, value),
    );
  }
}

// ─── Master dashboard / status review ──────────────────────────────────────

enum _DashReview {
  action, // pending + bought (not packed) — what still needs work
  pending,
  bought,
  packed,
  local,
  all,
}

class _Dashboard extends StatefulWidget {
  const _Dashboard({
    required this.stats,
    required this.meta,
    required this.items,
    required this.onOpenOwner,
    required this.onOpenLocal,
    required this.onOpenItem,
    required this.onPhoto,
    required this.photoBusyIds,
  });

  final ProgressStats stats;
  final TripMeta meta;
  final List<TripItem> items;
  final ValueChanged<String> onOpenOwner;
  final VoidCallback onOpenLocal;
  final ValueChanged<TripItem> onOpenItem;
  final ValueChanged<TripItem> onPhoto;
  final Set<String> photoBusyIds;

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  _DashReview _review = _DashReview.action;

  String _catName(String id) {
    for (final c in widget.meta.categories) {
      if (c.id == id) return c.name;
    }
    return id;
  }

  TripOwner? _owner(String id) {
    for (final o in widget.meta.owners) {
      if (o.id == id) return o;
    }
    return null;
  }

  List<TripItem> get _reviewItems {
    final all = List<TripItem>.from(widget.items);
    int rank(TripItem i) {
      // Priority first, then pending → bought → packed, name.
      final statusRank = switch (i.status) {
        ItemStatus.pending => 0,
        ItemStatus.bought => 1,
        ItemStatus.packed => 2,
      };
      return (i.priority ? 0 : 10) + statusRank;
    }

    bool match(TripItem i) => switch (_review) {
          _DashReview.action => !i.isLocal && !i.packed,
          _DashReview.pending => !i.isLocal && i.status == ItemStatus.pending,
          _DashReview.bought => !i.isLocal && i.status == ItemStatus.bought,
          _DashReview.packed => !i.isLocal && i.packed,
          _DashReview.local => i.isLocal,
          _DashReview.all => true,
        };

    final list = all.where(match).toList()
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        final ca = _catName(a.categoryId).compareTo(_catName(b.categoryId));
        if (ca != 0) return ca;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final preTrip = widget.items.where((i) => !i.isLocal).toList();
    final local = widget.items.where((i) => i.isLocal).toList();
    final pending = preTrip.where((i) => i.status == ItemStatus.pending).length;
    final bought = preTrip.where((i) => i.status == ItemStatus.bought).length;
    final packed = preTrip.where((i) => i.packed).length;
    final localPending = local.where((i) => !i.packed).length;
    final reviewItems = _reviewItems;

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 32),
      children: [
        Text('Master review', style: NzType.display.copyWith(fontSize: 18)),
        const SizedBox(height: 2),
        Text(
          'See what’s done and what’s still waiting — tap a row to edit.',
          style: NzType.body.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 10),
        // Status summary tiles
        Row(
          children: [
            Expanded(
              child: _countTile(
                'Pending',
                pending,
                NzChrome.danger,
                _DashReview.pending,
                emoji: '⏳',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _countTile(
                'Bought',
                bought,
                NzColors.bought,
                _DashReview.bought,
                emoji: '🛒',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _countTile(
                'Packed',
                packed,
                NzColors.success,
                _DashReview.packed,
                emoji: '🎒',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _countTile(
                'Local left',
                localPending,
                NzColors.lake,
                _DashReview.local,
                emoji: '🥝',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: NzColors.card.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NzColors.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text('✈️ Pre-trip', style: NzType.label.copyWith(fontSize: 11)),
                  const Spacer(),
                  Text(
                    '${stats.preTripPacked}/${stats.preTripTotal} packed · ${(stats.packedPct * 100).round()}%',
                    style: NzType.title.copyWith(
                      fontSize: 12,
                      color: NzColors.fern,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: stats.packedPct.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: NzColors.peak,
                  color: NzColors.fern,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('🛒 Bought ${(stats.boughtPct * 100).round()}%',
                      style: NzType.label.copyWith(fontSize: 10)),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onOpenLocal,
                    child: Text(
                      '🥝 Local ${stats.localPacked}/${stats.localTotal}',
                      style: NzType.label.copyWith(
                        fontSize: 10,
                        color: NzColors.lake,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text('By person', style: NzType.title.copyWith(fontSize: 13)),
        const SizedBox(height: 6),
        ...widget.meta.owners.map((o) {
          final color = Color(o.colorArgb);
          final s = stats.byOwner[o.id] ?? (total: 0, bought: 0, packed: 0);
          final boughtPct = s.total == 0 ? 0.0 : s.bought / s.total;
          final packedPct = s.total == 0 ? 0.0 : s.packed / s.total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: NzColors.card.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => widget.onOpenOwner(o.id),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            o.label,
                            style: NzType.title
                                .copyWith(fontSize: 13, color: color),
                          ),
                          const Spacer(),
                          Text(
                            '${s.total} items',
                            style: NzType.label.copyWith(fontSize: 10),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              size: 18, color: NzColors.muted),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _personPctRow(
                        label: 'Bought',
                        count: s.bought,
                        total: s.total,
                        pct: boughtPct,
                        color: NzColors.bought,
                      ),
                      const SizedBox(height: 6),
                      _personPctRow(
                        label: 'Packed',
                        count: s.packed,
                        total: s.total,
                        pct: packedPct,
                        color: NzColors.success,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Text('Item status', style: NzType.title.copyWith(fontSize: 14)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _reviewChip('Needs action', _DashReview.action, pending + bought),
              _reviewChip('Pending', _DashReview.pending, pending),
              _reviewChip('Bought', _DashReview.bought, bought),
              _reviewChip('Packed', _DashReview.packed, packed),
              _reviewChip('Local', _DashReview.local, local.length),
              _reviewChip('All', _DashReview.all, widget.items.length),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (reviewItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NzColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NzColors.cardBorder),
            ),
            child: Column(
              children: [
                Text(
                  _review == _DashReview.action ||
                          _review == _DashReview.pending
                      ? '✨ Nothing left here — nice work!'
                      : 'Nothing in this view',
                  style: NzType.title.copyWith(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Switch chips above to review other statuses.',
                  style: NzType.body.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._buildGrouped(reviewItems),
        const SizedBox(height: 12),
        Text(
          '${widget.items.length} items total · tap Refresh to sync the other phone',
          style: NzType.body.copyWith(fontSize: 11, color: NzColors.muted),
        ),
      ],
    );
  }

  List<Widget> _buildGrouped(List<TripItem> items) {
    // Group by status for "Needs action" / All; otherwise one flat list.
    if (_review == _DashReview.action || _review == _DashReview.all) {
      final groups = <String, List<TripItem>>{};
      for (final i in items) {
        final key = i.isLocal
            ? (i.packed ? 'Local · packed' : 'Local · still needed')
            : switch (i.status) {
                ItemStatus.pending => 'Pending — still need to buy',
                ItemStatus.bought => 'Bought — still need to pack',
                ItemStatus.packed => 'Packed ✓',
              };
        groups.putIfAbsent(key, () => []).add(i);
      }
      final order = [
        'Pending — still need to buy',
        'Bought — still need to pack',
        'Local · still needed',
        'Packed ✓',
        'Local · packed',
      ];
      final out = <Widget>[];
      for (final key in order) {
        final group = groups[key];
        if (group == null || group.isEmpty) continue;
        out.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Row(
            children: [
              Text(key, style: NzType.label.copyWith(fontSize: 11)),
              const Spacer(),
              Text('${group.length}', style: NzType.label.copyWith(fontSize: 11)),
            ],
          ),
        ));
        for (final item in group) {
          out.add(_statusRow(item));
        }
      }
      return out;
    }

    return [for (final item in items) _statusRow(item)];
  }

  Widget _personPctRow({
    required String label,
    required int count,
    required int total,
    required double pct,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: NzType.label.copyWith(fontSize: 11, color: color)),
            const Spacer(),
            Text(
              '$count/$total · ${(pct * 100).round()}%',
              style: NzType.title.copyWith(fontSize: 11.5, color: color),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: NzColors.peak,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _countTile(
    String label,
    int count,
    Color color,
    _DashReview review, {
    required String emoji,
  }) {
    final on = _review == review;
    return Material(
      color: on ? color.withValues(alpha: 0.2) : NzColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _review = review),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on ? color : NzColors.cardBorder,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              Text(
                '$count',
                style: NzType.display.copyWith(fontSize: 18, color: color),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NzType.label.copyWith(fontSize: 9.5, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewChip(String label, _DashReview review, int count) {
    final on = _review == review;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: on,
        showCheckmark: false,
        label: Text(
          '$label ($count)',
          style: NzType.label.copyWith(
            fontSize: 11,
            color: on ? NzColors.fern : NzColors.inkSoft,
          ),
        ),
        selectedColor: NzColors.fern.withValues(alpha: 0.18),
        backgroundColor: NzColors.card,
        side: BorderSide(
          color: on
              ? NzColors.fern.withValues(alpha: 0.55)
              : NzColors.cardBorder,
        ),
        onSelected: (_) => setState(() => _review = review),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _statusRow(TripItem item) {
    final owner = _owner(item.ownerId);
    final ownerColor = Color(owner?.colorArgb ?? 0xFF6B8F80);
    final statusColor = switch (item.status) {
      ItemStatus.pending => NzChrome.danger,
      ItemStatus.bought => NzColors.bought,
      ItemStatus.packed => NzColors.success,
    };
    final statusLabel = item.isLocal
        ? (item.packed ? 'Local ✓' : 'Buy in NZ')
        : item.status.label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: item.priority
            ? NzColors.priority.withValues(alpha: 0.28)
            : NzColors.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => widget.onOpenItem(item),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: item.priority
                    ? NzColors.gold.withValues(alpha: 0.55)
                    : NzColors.cardBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            if (item.priority)
                              const TextSpan(
                                text: '⭐ ',
                                style: TextStyle(fontSize: 12),
                              ),
                            TextSpan(
                              text: item.name,
                              style: NzType.title.copyWith(
                                fontSize: 13.5,
                                decoration: item.packed
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: item.packed
                                    ? NzColors.muted
                                    : NzColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_catName(item.categoryId)} · ${owner?.label ?? item.ownerId}'
                        '${item.recommendedQty.isNotEmpty ? ' · ${item.recommendedQty}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NzType.label.copyWith(fontSize: 10.5),
                      ),
                      if (item.note.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.note.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: NzType.body.copyWith(
                            fontSize: 11.5,
                            color: NzColors.inkSoft,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                NzItemPhotoButton(
                  photoBase64: item.photoBase64,
                  busy: widget.photoBusyIds.contains(item.id),
                  onPressed: () => widget.onPhoto(item),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: NzType.label.copyWith(
                      fontSize: 10,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: ownerColor.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Category + item rows ──────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.items,
    required this.done,
    required this.packedCount,
    required this.ownerOf,
    required this.onToggleBought,
    required this.onTogglePacked,
    required this.onEdit,
    required this.onDelete,
    required this.onPhoto,
    required this.photoBusyIds,
  });

  final TripCategory category;
  final List<TripItem> items;
  final bool done;
  final int packedCount;
  final TripOwner? Function(String id) ownerOf;
  final Future<void> Function(TripItem, bool) onToggleBought;
  final Future<void> Function(TripItem, bool) onTogglePacked;
  final ValueChanged<TripItem> onEdit;
  final ValueChanged<TripItem> onDelete;
  final ValueChanged<TripItem> onPhoto;
  final Set<String> photoBusyIds;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
          child: Row(
            children: [
              Text(
                done ? '✓ ${category.name}' : category.name,
                style: NzType.title.copyWith(
                  fontSize: 13.5,
                  color: done ? NzColors.success : NzColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              if (done)
                Text(
                  'Category packed! 🎒',
                  style: NzType.label.copyWith(color: NzColors.success),
                ),
              const Spacer(),
              Text(
                '$packedCount/${items.length}',
                style: NzType.label,
              ),
            ],
          ),
        ),
        ...items.map((item) => _ItemRow(
              item: item,
              owner: ownerOf(item.ownerId),
              onToggleBought: (v) => onToggleBought(item, v),
              onTogglePacked: (v) => onTogglePacked(item, v),
              onEdit: () => onEdit(item),
              onDelete: () => onDelete(item),
              onPhoto: () => onPhoto(item),
              photoBusy: photoBusyIds.contains(item.id),
            )),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.owner,
    required this.onToggleBought,
    required this.onTogglePacked,
    required this.onEdit,
    required this.onDelete,
    required this.onPhoto,
    required this.photoBusy,
  });

  final TripItem item;
  final TripOwner? owner;
  final ValueChanged<bool> onToggleBought;
  final ValueChanged<bool> onTogglePacked;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPhoto;
  final bool photoBusy;

  @override
  Widget build(BuildContext context) {
    final ownerColor = Color(owner?.colorArgb ?? 0xFF6B8F80);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: item.priority
            ? NzColors.priority.withValues(alpha: 0.28)
            : NzColors.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.priority
              ? NzColors.gold.withValues(alpha: 0.55)
              : NzColors.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: NzColors.fern.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onEdit,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (item.priority) ...[
                              const Text('⭐', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                item.name,
                                style: NzType.title.copyWith(
                                  fontSize: 14,
                                  decoration: item.packed
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: item.packed
                                      ? NzColors.muted
                                      : NzColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _tag(owner?.label ?? item.ownerId, ownerColor),
                            if (item.recommendedQty.isNotEmpty)
                              _tag('qty ${item.recommendedQty}', NzColors.muted),
                            if (item.quantity.isNotEmpty &&
                                item.quantity != item.recommendedQty)
                              _tag('plan ${item.quantity}', NzColors.inkSoft),
                          ],
                        ),
                        if (item.note.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: NzColors.skyTop.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: NzColors.lake.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              item.note.trim(),
                              style: NzType.body.copyWith(
                                fontSize: 12,
                                color: NzColors.inkSoft,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  NzTickButton(
                    label: 'Bought',
                    value: item.bought || item.packed,
                    onChanged: onToggleBought,
                    color: NzColors.bought,
                    reduceMotion: reduceMotion,
                  ),
                  const SizedBox(width: 8),
                  NzTickButton(
                    label: 'Packed',
                    value: item.packed,
                    onChanged: onTogglePacked,
                    color: NzColors.success,
                    reduceMotion: reduceMotion,
                  ),
                  const Spacer(),
                  NzItemPhotoButton(
                    photoBase64: item.photoBase64,
                    busy: photoBusy,
                    onPressed: onPhoto,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Edit',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: NzColors.fern,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: NzChrome.danger,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: NzType.label.copyWith(color: color, fontSize: 11),
      ),
    );
  }
}

// ─── Item editor ───────────────────────────────────────────────────────────

class _ItemEditorOutcome {
  const _ItemEditorOutcome.save(this.draft) : delete = false;
  const _ItemEditorOutcome.delete() : draft = null, delete = true;

  final _ItemDraft? draft;
  final bool delete;
}

class _ItemDraft {
  _ItemDraft({
    required this.name,
    required this.categoryId,
    required this.ownerId,
    required this.recommendedQty,
    required this.quantity,
    required this.note,
    required this.bought,
    required this.packed,
    required this.priority,
    required this.buyLocation,
  });

  String name;
  String categoryId;
  String ownerId;
  String recommendedQty;
  String quantity;
  String note;
  bool bought;
  bool packed;
  bool priority;
  BuyLocation buyLocation;

  TripItem toItem(String id) => TripItem(
        id: id,
        name: name.trim(),
        categoryId: categoryId,
        ownerId: ownerId,
        recommendedQty: recommendedQty.trim(),
        quantity: quantity.trim(),
        note: note.trim(),
        bought: bought || packed,
        packed: packed,
        priority: priority,
        buyLocation: buyLocation,
      );
}

class _ItemEditorSheet extends StatefulWidget {
  const _ItemEditorSheet({
    required this.meta,
    this.initial,
    required this.defaultOwnerId,
    required this.defaultLocal,
  });

  final TripMeta meta;
  final TripItem? initial;
  final String defaultOwnerId;
  final bool defaultLocal;

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _recQty;
  late final TextEditingController _qty;
  late final TextEditingController _note;
  late String _categoryId;
  late String _ownerId;
  late bool _bought;
  late bool _packed;
  late bool _priority;
  late BuyLocation _buyLocation;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    String? localCat;
    for (final c in widget.meta.categories) {
      if (c.isLocal) {
        localCat = c.id;
        break;
      }
    }
    final nonLocal = widget.meta.categories.where((c) => !c.isLocal);
    final defaultCat = widget.defaultLocal
        ? (localCat ?? widget.meta.categories.first.id)
        : (nonLocal.isEmpty
            ? widget.meta.categories.first.id
            : nonLocal.first.id);
    _name = TextEditingController(text: i?.name ?? '');
    _recQty = TextEditingController(text: i?.recommendedQty ?? '');
    _qty = TextEditingController(text: i?.quantity ?? '');
    _note = TextEditingController(text: i?.note ?? '');
    _categoryId = i?.categoryId ?? defaultCat;
    _ownerId = i?.ownerId ?? widget.defaultOwnerId;
    _bought = i?.bought ?? false;
    _packed = i?.packed ?? false;
    _priority = i?.priority ?? false;
    _buyLocation = i?.buyLocation ??
        (widget.defaultLocal
            ? BuyLocation.inNz
            : BuyLocation.beforeDeparture);
  }

  @override
  void dispose() {
    _name.dispose();
    _recQty.dispose();
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return NzSheetShell(
      title: editing ? 'Edit item' : 'Add item',
      emoji: editing ? '✏️' : '🎒',
      subtitle: editing
          ? 'Update packing details for both phones'
          : 'Toss another bit into the campervan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            decoration: NzChrome.input('Name'),
            textCapitalization: TextCapitalization.sentences,
            style: NzType.title.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _categoryId,
            decoration: NzChrome.input('Category'),
            items: widget.meta.categories
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, style: NzType.body),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _categoryId = v;
                for (final cat in widget.meta.categories) {
                  if (cat.id == v) {
                    _buyLocation = cat.isLocal
                        ? BuyLocation.inNz
                        : BuyLocation.beforeDeparture;
                    break;
                  }
                }
              });
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _ownerId,
            decoration: NzChrome.input('Owner'),
            items: widget.meta.owners
                .map(
                  (o) => DropdownMenuItem(
                    value: o.id,
                    child: Text(o.label, style: NzType.body),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _ownerId = v);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _recQty,
            decoration: NzChrome.input('Recommended qty (2p / 14d)'),
            style: NzType.body,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _qty,
            decoration: NzChrome.input('Planned quantity'),
            style: NzType.body,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: NzChrome.input('Note'),
            style: NzType.body,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<BuyLocation>(
            value: _buyLocation,
            decoration: NzChrome.input('Buy location'),
            items: BuyLocation.values
                .map(
                  (b) => DropdownMenuItem(
                    value: b,
                    child: Text(b.label, style: NzType.body),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _buyLocation = v);
            },
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Priority ⭐', style: NzType.title.copyWith(fontSize: 14)),
            value: _priority,
            activeColor: NzColors.gold,
            onChanged: (v) => setState(() => _priority = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Bought', style: NzType.title.copyWith(fontSize: 14)),
            value: _bought || _packed,
            activeColor: NzColors.bought,
            onChanged: (v) => setState(() {
              _bought = v;
              if (!v) _packed = false;
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Packed', style: NzType.title.copyWith(fontSize: 14)),
            value: _packed,
            activeColor: NzColors.success,
            onChanged: (v) => setState(() {
              _packed = v;
              if (v) _bought = true;
            }),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              if (_name.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                _ItemEditorOutcome.save(
                  _ItemDraft(
                    name: _name.text,
                    categoryId: _categoryId,
                    ownerId: _ownerId,
                    recommendedQty: _recQty.text,
                    quantity: _qty.text,
                    note: _note.text,
                    bought: _bought,
                    packed: _packed,
                    priority: _priority,
                    buyLocation: _buyLocation,
                  ),
                ),
              );
            },
            child: Text(editing ? 'Save changes' : 'Add to packing list'),
          ),
          if (editing) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: NzChrome.danger,
                side: BorderSide(color: NzChrome.danger.withValues(alpha: 0.55)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () async {
                final ok = await showNzConfirmDialog(
                  context: context,
                  title: 'Delete item?',
                  message:
                      'Remove “${widget.initial!.name}”? This syncs to both phones.',
                );
                if (!ok || !context.mounted) return;
                Navigator.pop(context, const _ItemEditorOutcome.delete());
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text('Delete item', style: NzType.title.copyWith(
                fontSize: 14,
                color: NzChrome.danger,
              )),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─── Manage owners / categories ────────────────────────────────────────────

class _ManageSheet extends StatefulWidget {
  const _ManageSheet({
    required this.meta,
    required this.onSaveMeta,
  });

  final TripMeta meta;
  final Future<void> Function(TripMeta) onSaveMeta;

  @override
  State<_ManageSheet> createState() => _ManageSheetState();
}

class _ManageSheetState extends State<_ManageSheet> {
  late List<TripOwner> _owners;
  late List<TripCategory> _categories;
  late TextEditingController _title;

  @override
  void initState() {
    super.initState();
    _owners = widget.meta.owners.map((o) => o.copyWith()).toList();
    _categories = widget.meta.categories.map((c) => c.copyWith()).toList();
    _title = TextEditingController(text: widget.meta.title);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    await widget.onSaveMeta(TripMeta(
      title: _title.text.trim().isEmpty ? widget.meta.title : _title.text.trim(),
      owners: _owners,
      categories: [
        for (var i = 0; i < _categories.length; i++)
          _categories[i].copyWith(order: i),
      ],
      seeded: true,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return NzSheetShell(
      title: 'Manage trip',
      emoji: '🗺️',
      subtitle: 'Changes save and sync to both phones',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            decoration: NzChrome.input('Trip title'),
            style: NzType.title.copyWith(fontSize: 15),
            onChanged: (_) => _persist(),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Text('✈️', style: TextStyle(fontSize: 22)),
            title: Text(
              'Departure date',
              style: NzType.title.copyWith(fontSize: 14),
            ),
            subtitle: Text(
              widget.meta.departureDate ?? 'Not set — tap to choose',
              style: NzType.body,
            ),
            trailing: const Icon(
              Icons.edit_calendar_rounded,
              color: NzColors.fern,
            ),
            onTap: () async {
              final initial =
                  widget.meta.departureDateTime ?? DateTime(2026, 9, 20);
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2025),
                lastDate: DateTime(2035),
                helpText: 'When do you fly to NZ?',
                builder: (ctx, child) => Theme(
                  data: NzChrome.of(ctx),
                  child: child!,
                ),
              );
              if (picked == null) return;
              final iso =
                  '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              await widget.onSaveMeta(widget.meta.copyWith(
                title: _title.text.trim().isEmpty
                    ? widget.meta.title
                    : _title.text.trim(),
                owners: _owners,
                categories: [
                  for (var i = 0; i < _categories.length; i++)
                    _categories[i].copyWith(order: i),
                ],
                departureDate: iso,
                seeded: true,
              ));
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
          Text('Owners', style: NzType.title),
          const SizedBox(height: 8),
          ..._owners.asMap().entries.map((e) {
            final i = e.key;
            final o = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextFormField(
                initialValue: o.label,
                style: NzType.body,
                decoration: NzChrome.input('Owner ${i + 1} (${o.id})'),
                onChanged: (v) {
                  _owners[i] = o.copyWith(label: v);
                  _persist();
                },
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Categories', style: NzType.title),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final id = 'cat_${DateTime.now().millisecondsSinceEpoch}';
                  setState(() {
                    _categories.add(TripCategory(
                      id: id,
                      name: 'New category',
                      order: _categories.length,
                    ));
                  });
                  await _persist();
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            onReorder: (oldIndex, newIndex) async {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final c = _categories.removeAt(oldIndex);
                _categories.insert(newIndex, c);
              });
              await _persist();
            },
            itemBuilder: (context, index) {
              final c = _categories[index];
              return Material(
                key: ValueKey(c.id),
                color: NzColors.card,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(
                    Icons.drag_handle_rounded,
                    color: NzColors.muted,
                  ),
                  title: TextFormField(
                    initialValue: c.name,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    style: NzType.body,
                    onChanged: (v) {
                      _categories[index] = c.copyWith(name: v);
                      _persist();
                    },
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Local checklist',
                        icon: Icon(
                          c.isLocal
                              ? Icons.storefront_rounded
                              : Icons.storefront_outlined,
                          color: c.isLocal ? NzColors.lake : NzColors.muted,
                        ),
                        onPressed: () async {
                          setState(() {
                            _categories[index] =
                                c.copyWith(isLocal: !c.isLocal);
                          });
                          await _persist();
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: NzChrome.danger,
                        ),
                        onPressed: () async {
                          final ok = await showNzConfirmDialog(
                            context: context,
                            title: 'Delete category?',
                            message:
                                'Delete “${c.name}”? Items stay but lose this group.',
                            emoji: '🗂️',
                          );
                          if (ok) {
                            setState(() => _categories.removeAt(index));
                            await _persist();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Changes save immediately and sync to both phones.',
            style: NzType.body.copyWith(fontSize: 11, color: NzColors.muted),
          ),
        ],
      ),
    );
  }
}
