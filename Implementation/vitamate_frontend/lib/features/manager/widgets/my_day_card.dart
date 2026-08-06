import 'package:flutter/material.dart';

import '../models/manager_models.dart';

class MyDayCard extends StatelessWidget {
  const MyDayCard({super.key, required this.day, this.onFocusTap});

  final ManagerDay day;
  final VoidCallback? onFocusTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF34136F),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2634136F),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: day.progressPercent / 100,
                      strokeWidth: 9,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      color: const Color(0xFF7DE6A4),
                    ),
                    Center(
                      child: Text(
                        '${day.score}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My day',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.completedGoals}/${day.totalGoals} health tasks completed',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onFocusTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7DE6A4).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF7DE6A4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day.focus.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: day.focus.progressPercent / 100,
                            minHeight: 7,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                            color: const Color(0xFF7DE6A4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (day.focus.rewardPoints > 0) ...[
                    const SizedBox(width: 10),
                    Text(
                      '+${day.focus.rewardPoints}',
                      style: const TextStyle(
                        color: Color(0xFF7DE6A4),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (day.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              day.message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
