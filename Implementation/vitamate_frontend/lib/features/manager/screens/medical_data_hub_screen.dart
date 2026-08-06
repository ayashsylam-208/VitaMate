import 'package:flutter/material.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../state/manager_overview_controller.dart';
import '../widgets/manager_section_tile.dart';

class MedicalDataHubScreen extends StatefulWidget {
  const MedicalDataHubScreen({super.key});

  @override
  State<MedicalDataHubScreen> createState() => _MedicalDataHubScreenState();
}

class _MedicalDataHubScreenState extends State<MedicalDataHubScreen> {
  late final ManagerOverviewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ManagerOverviewController()..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VitaMateTheme.shellBackground,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final overview = _controller.overview;
            if (_controller.isLoading && overview == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final medical = overview?.medical;
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  sliver: SliverList.list(
                    children: [
                      const _TopBar(),
                      const SizedBox(height: 18),
                      _MedicalHero(
                        title: medical == null
                            ? 'Medical data'
                            : '${medical.activeConditions} active conditions',
                        subtitle: medical?.conditionLabels.isEmpty == false
                            ? medical!.conditionLabels.join(', ')
                            : 'Keep medications and chronic-care data organized.',
                      ),
                      const SizedBox(height: 18),
                      ManagerSectionTile(
                        icon: Icons.medication_liquid_rounded,
                        title: 'Medications',
                        subtitle:
                            '${medical?.activeMedications ?? 0} active medication plans.',
                        onTap: () => Navigator.pushNamed(context, Routes.meds),
                      ),
                      const SizedBox(height: 12),
                      ManagerSectionTile(
                        icon: Icons.monitor_heart_outlined,
                        title: 'Chronic conditions',
                        subtitle:
                            '${medical?.activeConditions ?? 0} active conditions.',
                        onTap: () => Navigator.pushNamed(
                          context,
                          Routes.chronicConditions,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ManagerSectionTile(
                        icon: Icons.show_chart_rounded,
                        title: 'Health indicators',
                        subtitle:
                            '${medical?.healthIndicators ?? 0} recorded indicator values.',
                        onTap: () => Navigator.pushNamed(
                          context,
                          Routes.chronicConditions,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ManagerSectionTile(
                        icon: Icons.science_outlined,
                        title: 'Lab results',
                        subtitle: 'Lab tracking is linked from chronic care.',
                        onTap: () => Navigator.pushNamed(
                          context,
                          Routes.chronicConditions,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF8F3),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: VitaMateTheme.success.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: VitaMateTheme.success,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Medical data remains the source for health-critical reminders and chronic-care guidance.',
                                style: TextStyle(
                                  color: VitaMateTheme.primaryDeep,
                                  fontWeight: FontWeight.w800,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        const Expanded(
          child: Text(
            'Medical Data',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _MedicalHero extends StatelessWidget {
  const _MedicalHero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF34136F),
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.medical_information_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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
