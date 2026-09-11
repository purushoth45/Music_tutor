import 'package:flutter/material.dart';
import '../../../../app/constants/theme.dart';

class RecordingButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onPressed;

  const RecordingButton({
    Key? key,
    required this.isRecording,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isRecording
                ? [AppColors.error, AppColors.error.withOpacity(0.7)]
                : [AppColors.primary, AppColors.secondary],
          ),
          boxShadow: [
            BoxShadow(
              color: (isRecording ? AppColors.error : AppColors.primary)
                  .withOpacity(0.5),
              blurRadius: isRecording ? 24 : 12,
              spreadRadius: isRecording ? 4 : 0,
            ),
          ],
        ),
        child: Icon(
          isRecording ? Icons.stop : Icons.mic,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }
}
