import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/constants/theme.dart';
import '../../domain/entities/analysis_result.dart';
import '../bloc/audio_practice_bloc.dart';
import '../bloc/audio_practice_event.dart';
import '../bloc/audio_practice_state.dart';
import '../widgets/recording_button.dart';
import '../widgets/score_card.dart';
import '../widgets/note_capsule.dart';
import '../widgets/feedback_card.dart';
import '../widgets/animated_loader.dart';
import '../../../midi_practice/domain/models/exercise_model.dart';
import '../../../../core/user_session.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';

class AudioPracticeScreen extends StatefulWidget {
  const AudioPracticeScreen({Key? key}) : super(key: key);

  @override
  State<AudioPracticeScreen> createState() => _AudioPracticeScreenState();
}

class _AudioPracticeScreenState extends State<AudioPracticeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveformController;
  SkillLevel _selectedLevel = SkillLevel.beginner;

  @override
  void initState() {
    super.initState();
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _waveformController.dispose();
    super.dispose();
  }

  String get _levelTitle {
    switch (_selectedLevel) {
      case SkillLevel.beginner:
        return 'Beginner: Single Tones & Basic Pitch';
      case SkillLevel.moderate:
        return 'Moderate: Scale Intonation & Melodic Stability';
      case SkillLevel.pro:
        return 'Pro: Microtonal Accuracy & Rapid Vocal Drills';
    }
  }

  String get _levelSubtitle {
    switch (_selectedLevel) {
      case SkillLevel.beginner:
        return 'Sustain notes C4, E4, G4 into the mic. Generous pitch tolerance.';
      case SkillLevel.moderate:
        return 'Sing or play complete C Major scale at 85 BPM.';
      case SkillLevel.pro:
        return 'Strict fast-pitch detection with advanced resonance analysis.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () {
            context.go('/dashboard');
          },
        ),
        title: const Text('Audio AI Pitch Evaluation'),
      ),
      body: BlocBuilder<AudioPracticeBloc, AudioPracticeState>(
        builder: (context, state) {
          if (state is AudioAnalyzing) {
            return _buildLoadingView();
          } else if (state is AudioAnalysisComplete) {
            return _buildResultsView(state.result);
          } else if (state is AudioRecording) {
            return _buildRecordingView(context);
          } else if (state is AudioPracticeError) {
            return _buildErrorView(context, state.message);
          } else {
            return _buildInitialView(context);
          }
        },
      ),
    );
  }

  Widget _buildLevelSelector() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        children: SkillLevel.values.map((level) {
          final isSelected = _selectedLevel == level;
          Color accentColor = AppColors.primary;
          switch (level) {
            case SkillLevel.beginner:
              accentColor = AppColors.success;
              break;
            case SkillLevel.moderate:
              accentColor = AppColors.warning;
              break;
            case SkillLevel.pro:
              accentColor = AppColors.error;
              break;
          }

          final textColor = isSelected
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? AppColors.textSecondary : const Color(0xFF475569));

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedLevel = level;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? accentColor.withOpacity(0.25) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  border: isSelected
                      ? Border.all(color: accentColor, width: 1.5)
                      : null,
                  boxShadow: (isSelected && !isDark)
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(level.emoji, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      level.displayName,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecordingView(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = theme.textTheme.titleMedium?.color ?? Colors.white;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(12, (index) {
                return AnimatedBuilder(
                  animation: _waveformController,
                  builder: (context, child) {
                    final waveValue = sin(_waveformController.value * 2 * pi + index * pi / 6);
                    final height = 25 + (waveValue.abs() * 65);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: height,
                      width: 5,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Analyzing Audio (${_selectedLevel.displayName} Level)',
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _levelSubtitle,
            style: TextStyle(color: subtitleColor, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          RecordingButton(
            isRecording: true,
            onPressed: () {
              String exerciseId = 'beg_1';
              if (_selectedLevel == SkillLevel.moderate) exerciseId = 'mod_1';
              if (_selectedLevel == SkillLevel.pro) exerciseId = 'pro_1';
              final authState = context.read<AuthBloc>().state;
              int? currentUserId;
              if (authState is AuthAuthenticated) {
                currentUserId = int.tryParse(authState.user.id);
              } else if (UserSession.currentUser != null) {
                currentUserId = int.tryParse(UserSession.currentUser!.id);
              }
              context.read<AudioPracticeBloc>().add(
                StopRecordingEvent('', exerciseId, currentUserId),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(AnalysisResult result) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI Evaluation Results',
                style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Text(
                  'Overall: ${result.overallScore > 0 ? result.overallScore : result.accuracy}%',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Target vs Detected Notes Comparison Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.music, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Target Note Comparison (${_selectedLevel.displayName})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const Divider(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 120,
                      child: Text(
                        'Target Notes:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        result.targetNotesDisplay,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 120,
                      child: Text(
                        'Detected Notes:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        result.detectedNotesDisplay,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: (result.noteAccuracy >= 80 || result.accuracy >= 80)
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Score Cards Grid: Pitch Accuracy & Note Accuracy
          Row(
            children: [
              Expanded(
                child: ScoreCard(
                  label: 'Pitch Accuracy',
                  value: '${result.pitchAccuracy > 0 ? result.pitchAccuracy : result.accuracy}%',
                  icon: LucideIcons.target,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ScoreCard(
                  label: 'Note Accuracy',
                  value: '${result.noteAccuracy > 0 ? result.noteAccuracy : result.accuracy}%',
                  icon: LucideIcons.checkCircle,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Score Cards Grid: Timing Accuracy & Stability
          Row(
            children: [
              Expanded(
                child: ScoreCard(
                  label: 'Timing Accuracy',
                  value: '${result.timingAccuracy > 0 ? result.timingAccuracy : 85}%',
                  icon: LucideIcons.clock,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ScoreCard(
                  label: 'Stability Rating',
                  value: '${result.stability}/10',
                  icon: LucideIcons.activity,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          FeedbackCard(
            title: 'AI Vocal & Audio Coach',
            message: result.feedback,
          ),

          if (result.coachingTips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : Colors.white,
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(LucideIcons.lightbulb, size: 16, color: AppColors.warning),
                      SizedBox(width: 8),
                      Text('AI Coaching Insights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...result.coachingTips.map((tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        Expanded(child: Text(tip, style: const TextStyle(fontSize: 13, height: 1.3))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          Text(
            'Detected Pitch Intonation',
            style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: result.notes.map((note) {
              return NoteCapsule(
                note: note.note,
                accuracy: note.accuracy,
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<AudioPracticeBloc>().add(const ResetEvent());
              },
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('Practice Again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialView(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = theme.textTheme.titleLarge?.color ?? Colors.white;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Level selector
          _buildLevelSelector(),
          const SizedBox(height: AppSpacing.xl),

          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white.withOpacity(0.01) : AppColors.primary.withOpacity(0.06),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.04) : AppColors.primary.withOpacity(0.2),
              ),
            ),
            child: Icon(
              LucideIcons.mic,
              size: 72,
              color: isDark ? Colors.white.withOpacity(0.2) : AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            _levelTitle,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _levelSubtitle,
            style: TextStyle(color: subtitleColor, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          RecordingButton(
            isRecording: false,
            onPressed: () {
              context.read<AudioPracticeBloc>().add(const StartRecordingEvent());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    final theme = Theme.of(context);
    final titleColor = theme.textTheme.titleMedium?.color ?? Colors.white;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AnimatedLoader(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Evaluating ${_selectedLevel.displayName} Level Performance...',
            style: TextStyle(
              color: titleColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Processing frequency spectrum and pitch accuracy',
            style: TextStyle(color: subtitleColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String message) {
    final theme = Theme.of(context);
    final titleColor = theme.textTheme.titleMedium?.color ?? Colors.white;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.circleAlert, color: AppColors.error, size: 48),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Analysis Notice',
              style: TextStyle(
                color: titleColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () {
                context.read<AudioPracticeBloc>().add(const ResetEvent());
              },
              icon: const Icon(LucideIcons.rotateCcw, size: 16),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
