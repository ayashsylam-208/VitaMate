import 'package:flutter/material.dart';

import '../../../shared/widgets/vitamate_bottom_nav.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      bottomNavigationBar: VitaMateBottomNav(currentIndex: -1),
      body: Center(child: Text('Goals Screen')),
    );
  }
}
