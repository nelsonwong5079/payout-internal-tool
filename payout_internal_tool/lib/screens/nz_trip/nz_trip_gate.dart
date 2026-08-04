import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nz_trip_theme.dart';
import 'nz_trip_widgets.dart';

/// Obscure path — not linked from the app UI. Bookmark this on your phones.
const String kNzTripRoute = '/p/kf9w2m7x';

/// Shared PIN for Me & Cat. Change here if you want a new code.
const String kNzTripPin = '0329';

const _sessionKey = 'nz_trip_unlocked_v1';

bool nzTripSessionUnlocked() =>
    html.window.sessionStorage[_sessionKey] == '1';

void nzTripUnlockSession() {
  html.window.sessionStorage[_sessionKey] = '1';
}

void nzTripLockSession() {
  html.window.sessionStorage.remove(_sessionKey);
}

/// PIN gate before the packing tracker. Remembers unlock for this browser tab.
class NzTripPinGate extends StatefulWidget {
  const NzTripPinGate({super.key, required this.child});

  final Widget child;

  @override
  State<NzTripPinGate> createState() => _NzTripPinGateState();
}

class _NzTripPinGateState extends State<NzTripPinGate> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _unlocked = nzTripSessionUnlocked();
    if (!_unlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final entered = _ctrl.text.trim();
    if (entered == kNzTripPin) {
      nzTripUnlockSession();
      setState(() {
        _unlocked = true;
        _error = null;
      });
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _error = 'Wrong code';
      _ctrl.clear();
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;

    return Theme(
      data: NzChrome.of(context),
      child: Scaffold(
        backgroundColor: NzColors.snow,
        body: NzAdventureBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🥝', style: const TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      Text(
                        'Private packing list',
                        style: NzType.display.copyWith(fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter the shared code to continue.',
                        style: NzType.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        obscureText: true,
                        obscuringCharacter: '•',
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: NzType.display.copyWith(
                          fontSize: 28,
                          letterSpacing: 8,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                        ],
                        decoration: NzChrome.input('Code').copyWith(
                          hintText: '••••',
                          hintStyle: NzType.display.copyWith(
                            fontSize: 28,
                            letterSpacing: 8,
                            color: NzColors.muted.withValues(alpha: 0.4),
                          ),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: NzType.label.copyWith(color: NzChrome.danger),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Text('Unlock'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            Navigator.of(context).pushReplacementNamed('/');
                          }
                        },
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
