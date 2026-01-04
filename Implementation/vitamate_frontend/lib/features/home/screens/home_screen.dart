import 'package:flutter/material.dart';
import '../state/home_controller.dart';
import '../widgets/module_card.dart';
import '../../../core/routing/routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController controller;

  @override
  void initState() {
    super.initState();
    controller = HomeController()..load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Progress',
            onPressed: () => Navigator.pushNamed(context, Routes.progress),
            icon: const Icon(Icons.insights),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.loading ? null : controller.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.error != null) {
              return _ErrorState(
                message: controller.error!,
                onRetry: controller.load,
              );
            }

            final d = controller.data;

            return RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ✅ Points hero card (no score endpoint / no details button)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          cs.primary.withOpacity(0.95),
                          cs.secondary.withOpacity(0.85),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.stars,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your points',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${d.points}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Earn points by completing your daily habits.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ✅ Personal goal = Custom personal goal tracker (not diet goal)
                  _SectionHeader(
                    title: 'Personal Goal Tracker',
                    actionText: 'Open',
                    onAction: () => Navigator.pushNamed(context, Routes.goal),
                  ),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.pushNamed(context, Routes.goal),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.flag, color: cs.primary),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create your own goal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Track a custom objective outside the main trackers.',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  _SectionHeader(
                    title: 'Trackers',
                    actionText: 'Statistics',
                    onAction: () =>
                        Navigator.pushNamed(context, Routes.progress),
                  ),
                  const SizedBox(height: 8),

                  // ✅ Fix text wrap by increasing aspect ratio + ModuleCard ellipsis
                  GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio:
                        1.55, // ✅ was 1.35 (caused last letter wrap)
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      ModuleCard(
                        icon: Icons.directions_walk,
                        title: 'Steps',
                        subtitle: 'Today: ${d.todaySteps}',
                        onTap: () => Navigator.pushNamed(context, Routes.steps),
                      ),
                      ModuleCard(
                        icon: Icons.local_drink,
                        title: 'Water',
                        subtitle: 'Today: ${d.waterMl} ml',
                        onTap: () => Navigator.pushNamed(context, Routes.water),
                      ),
                      ModuleCard(
                        icon: Icons.local_fire_department,
                        title: 'Calories',
                        subtitle: 'Today: ${d.calories} kcal',
                        onTap: () => Navigator.pushNamed(context, Routes.meals),
                      ),
                      ModuleCard(
                        icon: Icons.bedtime,
                        title: 'Sleep',
                        subtitle: 'Today: ${d.sleepMinutes} min',
                        onTap: () => Navigator.pushNamed(context, Routes.sleep),
                      ),
                      ModuleCard(
                        icon: Icons.fitness_center,
                        title: 'Activity',
                        subtitle: 'Log workouts',
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.activities),
                      ),
                      ModuleCard(
                        icon: Icons.insights,
                        title: 'Progress',
                        subtitle: 'Trends & charts',
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.progress),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const Spacer(),
        TextButton(onPressed: onAction, child: Text(actionText)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 44),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
