import 'package:flutter/material.dart';

import '../state/water_controller.dart';
import 'hydration_overview_screen.dart';

class WaterScreen extends StatelessWidget {
  const WaterScreen({
    super.key,
    this.targetValueFromBackend = 0,
    this.targetIsLiters = true,
    this.controller,
    this.autoLoad = true,
  });

  final double targetValueFromBackend;
  final bool targetIsLiters;
  final WaterController? controller;
  final bool autoLoad;

  @override
  Widget build(BuildContext context) {
    return HydrationOverviewScreen(controller: controller, autoLoad: autoLoad);
  }
}
