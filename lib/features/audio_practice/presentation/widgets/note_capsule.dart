import 'package:flutter/material.dart';
import '../../../../app/constants/theme.dart';

class NoteCapsule extends StatelessWidget {
  final String note;
  final int? accuracy;
  final bool isActive;

  const NoteCapsule({
    Key? key,
    required this.note,
    this.accuracy,
    this.isActive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color capsuleColor;
    Color textColor;
    BoxBorder border;

    if (accuracy != null) {
      if (accuracy! >= 90) {
        capsuleColor = AppColors.success.withOpacity(0.15);
        textColor = isDark ? AppColors.success : const Color(0xFF047857);
        border = Border.all(color: AppColors.success.withOpacity(0.5), width: 1.5);
      } else if (accuracy! >= 80) {
        capsuleColor = AppColors.warning.withOpacity(0.15);
        textColor = isDark ? AppColors.warning : const Color(0xFFB45309);
        border = Border.all(color: AppColors.warning.withOpacity(0.5), width: 1.5);
      } else {
        capsuleColor = AppColors.error.withOpacity(0.15);
        textColor = isDark ? AppColors.error : const Color(0xFFB91C1C);
        border = Border.all(color: AppColors.error.withOpacity(0.5), width: 1.5);
      }
    } else {
      if (isActive) {
        capsuleColor = AppColors.secondary.withOpacity(0.2);
        textColor = isDark ? AppColors.secondary : AppColors.primary;
        border = Border.all(color: isDark ? AppColors.secondary : AppColors.primary, width: 2.0);
      } else {
        capsuleColor = isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0);
        textColor = isDark ? AppColors.textSecondary : const Color(0xFF334155);
        border = Border.all(color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFCBD5E1), width: 1.0);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: capsuleColor,
        borderRadius: BorderRadius.circular(20),
        border: border,
        boxShadow: isActive || (accuracy != null && accuracy! >= 90)
            ? [
                BoxShadow(
                  color: textColor.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            note,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (accuracy != null) ...[
            const SizedBox(width: 4),
            Text(
              '$accuracy%',
              style: TextStyle(
                color: textColor.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
