import 'package:flutter/material.dart';

import 'nz_trip_gate.dart';
import 'nz_trip_screen.dart';

/// Private entry — obscure URL + PIN. No PE Ops sign-in required.
class NzTripPage extends StatelessWidget {
  const NzTripPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const NzTripPinGate(
      child: NzTripScreen(),
    );
  }
}
