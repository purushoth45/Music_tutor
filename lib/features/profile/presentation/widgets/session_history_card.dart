import 'package:flutter/material.dart';
import '../../../../app/constants/theme.dart';
import '../../../../shared/widgets/glass_card.dart';

class SessionHistoryCard extends StatelessWidget {
  final String title;
  final String date;
  final String score;
  final String type;

  const SessionHistoryCard({
    Key? key,
    required this.title,
    required this.date,
    required this.score,
    required this.type,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMidi = type.toLowerCase() == 'midi';
    final typeColor = isMidi ? AppColors.primary : AppColors.secondary;
    final titleColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final dateColor = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Title and Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    color: dateColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Right side: Score and Type Pill
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score,
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: typeColor.withOpacity(0.12),
                  border: Border.all(color: typeColor.withOpacity(0.3), width: 1),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
