import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nz_trip_theme.dart';

/// Soft NZ sky → hills backdrop for this section only.
class NzAdventureBackground extends StatelessWidget {
  const NzAdventureBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                NzColors.skyTop,
                NzColors.skyMid,
                Color(0xFFE8F6EF),
                NzColors.snow,
              ],
              stops: [0, 0.28, 0.65, 1],
            ),
          ),
        ),
        // Soft hills only at bottom — keep top clear for list space
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 100,
          child: CustomPaint(painter: _HillsPainter()),
        ),
        child,
      ],
    );
  }
}

class _HillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final back = Paint()..color = NzColors.hill.withValues(alpha: 0.55);
    final front = Paint()..color = NzColors.fernLight.withValues(alpha: 0.35);
    final p1 = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.15, size.width * 0.55, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.75, size.width, size.height * 0.4)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(p1, back);
    final p2 = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.4, size.width * 0.7, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.9, size.height * 0.8, size.width, size.height * 0.55)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(p2, front);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Compact countdown chip for the phone header row.
class NzCountdownChip extends StatelessWidget {
  const NzCountdownChip({
    super.key,
    required this.departureDate,
    required this.onEditDate,
  });

  final DateTime? departureDate;
  final VoidCallback onEditDate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String label;
    if (departureDate == null) {
      label = 'Set date ✈️';
    } else {
      final dep = DateTime(
        departureDate!.year,
        departureDate!.month,
        departureDate!.day,
      );
      final days = dep.difference(today).inDays;
      if (days > 1) {
        label = '$days days ✈️';
      } else if (days == 1) {
        label = 'Tomorrow ✈️';
      } else if (days == 0) {
        label = 'Today! 🎉';
      } else {
        label = 'In NZ 🥝';
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEditDate,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF8E7), Color(0xFFE0F7FA)],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: NzColors.gold.withValues(alpha: 0.5)),
          ),
          child: Text(
            label,
            style: NzType.label.copyWith(color: NzColors.ink, fontSize: 11.5),
          ),
        ),
      ),
    );
  }
}

/// Journey progress — campervan travels home → NZ as % rises.
class NzJourneyProgress extends StatelessWidget {
  const NzJourneyProgress({
    super.key,
    required this.overallPct,
    required this.scopePct,
    required this.scopeLabel,
    required this.boughtPct,
    required this.packedLabel,
    required this.cheer,
    required this.mePct,
    required this.catPct,
    required this.meLabel,
    required this.catLabel,
    required this.reduceMotion,
  });

  final double overallPct;
  final double scopePct;
  final String scopeLabel;
  final double boughtPct;
  final String packedLabel;
  final String cheer;
  final double mePct;
  final double catPct;
  final String meLabel;
  final String catLabel;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final pct = scopePct.clamp(0.0, 1.0);
    final overall = (overallPct * 100).round();
    final emoji = NzMilestones.scenicEmoji(overallPct);
    final secondary = scopeLabel == 'Overall'
        ? 'Bought ${(boughtPct * 100).round()}%'
        : 'Trip $overall%';

    return Tooltip(
      message: cheer,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
        decoration: BoxDecoration(
          color: NzColors.card.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NzColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 3),
                Text(
                  '${(pct * 100).round()}%',
                  style:
                      NzType.title.copyWith(fontSize: 13, color: NzColors.fern),
                ),
                const SizedBox(width: 6),
                Text(packedLabel, style: NzType.label.copyWith(fontSize: 10)),
                const Spacer(),
                _miniPct(meLabel, mePct, NzColors.me),
                const SizedBox(width: 4),
                _miniPct(catLabel, catPct, NzColors.cat),
                const SizedBox(width: 4),
                Text(secondary, style: NzType.label.copyWith(fontSize: 9.5)),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 18,
              child: LayoutBuilder(
                builder: (context, c) {
                  final travel = (c.maxWidth - 20) * pct;
                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: [
                              NzColors.hill,
                              NzColors.lake.withValues(alpha: 0.55),
                              NzColors.fernLight,
                            ],
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 420),
                        curve: Curves.easeOutBack,
                        left: travel,
                        child:
                            const Text('🚐', style: TextStyle(fontSize: 13)),
                      ),
                      const Positioned(
                        right: 0,
                        child: Text('🥝', style: TextStyle(fontSize: 10)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPct(String label, double pct, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${label.isEmpty ? '?' : label.characters.first}${(pct * 100).round()}%',
        style: NzType.label.copyWith(color: color, fontSize: 9.5),
      ),
    );
  }
}

/// Bouncy bought / packed control.
class NzTickButton extends StatefulWidget {
  const NzTickButton({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
    required this.reduceMotion,
  });

  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  final bool reduceMotion;

  @override
  State<NzTickButton> createState() => _NzTickButtonState();
}

class _NzTickButtonState extends State<NzTickButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _bounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.18), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 0.94), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant NzTickButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value && !oldWidget.value && !widget.reduceMotion) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: widget.reduceMotion ? const AlwaysStoppedAnimation(1) : _bounce,
      child: Material(
        color: widget.value
            ? widget.color.withValues(alpha: 0.18)
            : NzColors.snow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onChanged(!widget.value);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.value
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 20,
                  color: widget.value ? widget.color : NzColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: NzType.label.copyWith(
                    color: widget.value ? widget.color : NzColors.inkSoft,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight confetti burst for milestones.
class NzConfettiBurst extends StatefulWidget {
  const NzConfettiBurst({
    super.key,
    required this.active,
    required this.reduceMotion,
  });

  final bool active;
  final bool reduceMotion;

  @override
  State<NzConfettiBurst> createState() => _NzConfettiBurstState();
}

class _NzConfettiBurstState extends State<NzConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rand = math.Random();
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _particles = _spawn();
  }

  List<_Particle> _spawn() => List.generate(28, (_) {
        return _Particle(
          dx: _rand.nextDouble() * 2 - 1,
          dy: _rand.nextDouble() * 0.6 + 0.2,
          color: [
            NzColors.gold,
            NzColors.lake,
            NzColors.fernLight,
            NzColors.cat,
            NzColors.me,
          ][_rand.nextInt(5)],
          size: 4 + _rand.nextDouble() * 5,
          spin: _rand.nextDouble() * math.pi,
        );
      });

  @override
  void didUpdateWidget(covariant NzConfettiBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && !widget.reduceMotion) {
      _particles = _spawn();
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          if (_ctrl.value == 0 && !widget.active) {
            return const SizedBox.shrink();
          }
          return CustomPaint(
            painter: _ConfettiPainter(_particles, _ctrl.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.dx,
    required this.dy,
    required this.color,
    required this.size,
    required this.spin,
  });
  final double dx, dy, size, spin;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.28;
    for (final p in particles) {
      final x = cx + p.dx * size.width * 0.45 * t;
      final y = cy + p.dy * size.height * 0.55 * t + 40 * t * t;
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - t).clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin + t * 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}

class NzMilestoneBanner extends StatelessWidget {
  const NzMilestoneBanner({super.key, required this.message, required this.emoji});

  final String message;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NzColors.gold.withValues(alpha: 0.35),
            NzColors.lake.withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NzColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NzType.cheer.copyWith(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class NzAllDoneOverlay extends StatelessWidget {
  const NzAllDoneOverlay({
    super.key,
    required this.visible,
    required this.onDismiss,
  });

  final bool visible;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Material(
      color: NzColors.night.withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
            decoration: BoxDecoration(
              color: NzColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: NzColors.gold, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉🥝🏔️', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 12),
                Text(
                  "You're ready for\nNew Zealand!",
                  textAlign: TextAlign.center,
                  style: NzType.display.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  'Suitcases packed · lakes, peaks & starry skies await.',
                  textAlign: TextAlign.center,
                  style: NzType.body,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: NzColors.fern,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onDismiss,
                  child: Text('Let\'s go! ✈️', style: NzType.title.copyWith(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Drag-handle + title shell used by add/edit/manage/filter sheets.
class NzSheetShell extends StatelessWidget {
  const NzSheetShell({
    super.key,
    required this.title,
    required this.child,
    this.emoji,
    this.subtitle,
  });

  final String title;
  final String? emoji;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Theme(
      data: NzChrome.of(context),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F6EF), NzColors.snow],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: NzColors.cardBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (emoji != null) ...[
                      Text(emoji!, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: NzType.display.copyWith(fontSize: 18)),
                          if (subtitle != null)
                            Text(subtitle!, style: NzType.body.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> showNzConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
  bool destructive = true,
  String emoji = '🗑️',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Theme(
      data: NzChrome.of(ctx),
      child: AlertDialog(
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  destructive ? NzChrome.danger : NzColors.fern,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}

Future<T?> showNzSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Theme(
      data: NzChrome.of(ctx),
      child: builder(ctx),
    ),
  );
}

Uint8List? nzDecodePhoto(String base64) {
  final raw = base64.trim();
  if (raw.isEmpty) return null;
  try {
    return base64Decode(raw);
  } catch (_) {
    return null;
  }
}

/// Compact photo button / thumbnail for packing list rows.
class NzItemPhotoButton extends StatelessWidget {
  const NzItemPhotoButton({
    super.key,
    required this.photoBase64,
    required this.onPressed,
    this.busy = false,
  });

  final String photoBase64;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bytes = nzDecodePhoto(photoBase64);
    final hasPhoto = bytes != null;
    return Material(
      color: hasPhoto
          ? NzColors.lake.withValues(alpha: 0.12)
          : NzColors.snow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: busy ? null : onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 40,
          height: 40,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NzColors.fern,
                  ),
                )
              : hasPhoto
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          size: 20,
                          color: NzColors.muted,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.add_a_photo_outlined,
                      size: 20,
                      color: NzColors.fern,
                    ),
        ),
      ),
    );
  }
}

Future<void> showNzPhotoViewer({
  required BuildContext context,
  required String title,
  required String photoBase64,
  required VoidCallback onReplace,
  required VoidCallback onRemove,
}) {
  final bytes = nzDecodePhoto(photoBase64);
  return showDialog<void>(
    context: context,
    builder: (ctx) => Theme(
      data: NzChrome.of(ctx),
      child: Dialog(
        backgroundColor: NzColors.night,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  const Text('📸', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NzType.title.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.55,
              ),
              child: bytes == null
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Could not load photo',
                        style: NzType.body.copyWith(color: Colors.white70),
                      ),
                    )
                  : InteractiveViewer(
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onReplace();
                      },
                      icon: const Icon(Icons.cameraswitch_outlined, size: 18),
                      label: const Text('Replace'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: NzChrome.danger,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onRemove();
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
