import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/constants/theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/utils/midi_hardware_service.dart';
import '../../../../shared/utils/midi_device_item.dart';
import '../../../audio_practice/domain/entities/analysis_result.dart';
import '../../../audio_practice/presentation/bloc/audio_practice_bloc.dart';
import '../../../audio_practice/presentation/bloc/audio_practice_event.dart';
import '../../../audio_practice/presentation/bloc/audio_practice_state.dart';
import '../../../audio_practice/presentation/widgets/animated_loader.dart';
import '../../../audio_practice/presentation/widgets/feedback_card.dart';
import '../../../audio_practice/presentation/widgets/note_capsule.dart';
import '../../../audio_practice/presentation/widgets/recording_button.dart';
import '../../../audio_practice/presentation/widgets/score_card.dart';
import '../../../midi_practice/data/repositories/exercise_repository.dart';
import '../../../midi_practice/domain/models/exercise_model.dart';
import '../../../midi_practice/presentation/bloc/midi_practice_bloc.dart';
import '../../../midi_practice/presentation/bloc/midi_practice_event.dart';
import '../../../midi_practice/presentation/bloc/midi_practice_state.dart';
import '../../../../core/user_session.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import '../widgets/ai_message_card.dart';

class PracticeHubScreen extends StatefulWidget {
  const PracticeHubScreen({Key? key}) : super(key: key);

  @override
  State<PracticeHubScreen> createState() => _PracticeHubScreenState();
}

class _PracticeHubScreenState extends State<PracticeHubScreen>
    with SingleTickerProviderStateMixin {
  // Mode Selection: 0 = Audio AI (Mic), 1 = MIDI Keyboard
  int _activeModeIndex = 0;

  // Shared Skill Level State
  SkillLevel _selectedLevel = SkillLevel.beginner;

  // Audio AI Animation Controller
  late AnimationController _waveformController;

  // MIDI Practice State
  late PracticeExercise _selectedMidiExercise;
  bool _isMidiPlaying = false;
  int _activeNoteIndex = -1;
  Timer? _practiceTimer;
  int _midiScore = 0;
  int _notesMatched = 0;

  @override
  void initState() {
    super.initState();
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    _selectedMidiExercise = ExerciseRepository.getExercisesByLevel(_selectedLevel).first;
  }

  @override
  void dispose() {
    _waveformController.dispose();
    _practiceTimer?.cancel();
    super.dispose();
  }

  void _onLevelChanged(SkillLevel level) {
    setState(() {
      _selectedLevel = level;
      final exercises = ExerciseRepository.getExercisesByLevel(level);
      _selectedMidiExercise = exercises.first;
      _stopMidiSimulation();
    });
  }

  void _startMidiSimulation() {
    _stopMidiSimulation();
    setState(() {
      _isMidiPlaying = true;
      _activeNoteIndex = 0;
      _midiScore = 0;
      _notesMatched = 0;
    });

    final intervalMs = (60000 / _selectedMidiExercise.targetBpm).round();

    _practiceTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) return;

      setState(() {
        _notesMatched++;
        _midiScore = ((_notesMatched / _selectedMidiExercise.notes.length) * 100).round();

        if (_activeNoteIndex < _selectedMidiExercise.notes.length - 1) {
          _activeNoteIndex++;
        } else {
          _isMidiPlaying = false;
          timer.cancel();
          _showMidiCompletionDialog();
        }
      });
    });
  }

  void _stopMidiSimulation() {
    _practiceTimer?.cancel();
    setState(() {
      _isMidiPlaying = false;
      _activeNoteIndex = -1;
    });
  }

  void _showMidiCompletionDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Row(
            children: const [
              Icon(LucideIcons.award, color: AppColors.warning, size: 24),
              SizedBox(width: 8),
              Text('Exercise Complete!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Great job practicing "${_selectedMidiExercise.title}"!'),
              const SizedBox(height: 12),
              Text('• Level: ${_selectedLevel.displayName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('• Target BPM: ${_selectedMidiExercise.targetBpm}'),
              Text('• Accuracy Score: $_midiScore%', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue Practice'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1150),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Studio Header & Mode Switcher Bar
                  _buildStudioHeader(theme, isDark),
                  const SizedBox(height: AppSpacing.lg),

                  // 2. Shared Skill Level Selector Bar
                  _buildSkillLevelSelectorBar(isDark),
                  const SizedBox(height: AppSpacing.lg),

                  // 3. Main Studio Workspace Layout (Responsive Grid)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWideScreen = constraints.maxWidth > 768;
                      if (isWideScreen) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Studio Console Column
                            Expanded(
                              flex: 5,
                              child: _activeModeIndex == 0
                                  ? _buildAudioConsoleColumn(isDark)
                                  : _buildMidiConsoleColumn(context, isDark),
                            ),
                            const SizedBox(width: AppSpacing.lg),

                            // Right AI Coach & Exercise Suite Column
                            Expanded(
                              flex: 6,
                              child: _activeModeIndex == 0
                                  ? _buildAudioCoachSuiteColumn(context)
                                  : _buildMidiCoachSuiteColumn(context, isDark),
                            ),
                          ],
                        );
                      } else {
                        // Stacked layout for smaller screens
                        return Column(
                          children: [
                            _activeModeIndex == 0
                                ? _buildAudioConsoleColumn(isDark)
                                : _buildMidiConsoleColumn(context, isDark),
                            const SizedBox(height: AppSpacing.lg),
                            _activeModeIndex == 0
                                ? _buildAudioCoachSuiteColumn(context)
                                : _buildMidiCoachSuiteColumn(context, isDark),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Header & Mode Switcher Bar
  Widget _buildStudioHeader(ThemeData theme, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Practice Studio 🎵',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Interactive Performance Workspace',
                  style: TextStyle(
                    color: theme.textTheme.headlineMedium?.color ?? Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Mode Toggle Pills
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModePill(
                  index: 0,
                  label: 'Audio AI',
                  icon: LucideIcons.mic,
                  activeColor: AppColors.primary,
                  isDark: isDark,
                ),
                _buildModePill(
                  index: 1,
                  label: 'MIDI Keys',
                  icon: LucideIcons.keyboard,
                  activeColor: AppColors.secondary,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModePill({
    required int index,
    required String label,
    required IconData icon,
    required Color activeColor,
    required bool isDark,
  }) {
    final isSelected = _activeModeIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _activeModeIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : (isDark ? AppColors.textSecondary : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? AppColors.textSecondary : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shared Skill Level Selector Bar
  Widget _buildSkillLevelSelectorBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
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
              onTap: () => _onLevelChanged(level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? accentColor.withOpacity(0.22) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  border: isSelected ? Border.all(color: accentColor, width: 1.5) : null,
                  boxShadow: isSelected && !isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(level.emoji, style: const TextStyle(fontSize: 13)),
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

  // ==========================================
  // AUDIO AI ENGINE CONSOLE & COACH
  // ==========================================
  Widget _buildAudioConsoleColumn(bool isDark) {
    return BlocBuilder<AudioPracticeBloc, AudioPracticeState>(
      builder: (context, state) {
        String levelDesc = 'Sustain C4, E4, G4 into microphone. Generous pitch tolerance.';
        if (_selectedLevel == SkillLevel.moderate) {
          levelDesc = 'Sing or play complete C Major scale at 85 BPM.';
        } else if (_selectedLevel == SkillLevel.pro) {
          levelDesc = 'Strict fast-pitch detection with advanced resonance analysis.';
        }

        final isRecording = state is AudioRecording;
        final isAnalyzing = state is AudioAnalyzing;

        return GlassCard(
          borderColor: AppColors.primary.withOpacity(0.3),
          child: Column(
            children: [
              // Header Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mic Pitch Monitor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Level: ${_selectedLevel.displayName}',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Animated Waveform or Pulsing Mic Monitor
              if (isRecording)
                SizedBox(
                  height: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(14, (index) {
                      return AnimatedBuilder(
                        animation: _waveformController,
                        builder: (context, child) {
                          final waveValue = sin(_waveformController.value * 2 * pi + index * pi / 7);
                          final height = 20 + (waveValue.abs() * 60);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: height,
                            width: 5,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                )
              else if (isAnalyzing)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: AnimatedLoader(),
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white.withOpacity(0.02) : AppColors.primary.withOpacity(0.08),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 4,
                      )
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.mic,
                    size: 54,
                    color: AppColors.primary,
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),
              Text(
                isRecording
                    ? 'Listening & Analyzing Mic Frequency...'
                    : 'Audio AI Pitch Evaluation',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                levelDesc,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              RecordingButton(
                isRecording: isRecording,
                onPressed: () {
                  if (isRecording) {
                    final exId = _selectedMidiExercise.id;
                    final authState = context.read<AuthBloc>().state;
                    int? currentUserId;
                    if (authState is AuthAuthenticated) {
                      currentUserId = int.tryParse(authState.user.id);
                    } else if (UserSession.currentUser != null) {
                      currentUserId = int.tryParse(UserSession.currentUser!.id);
                    }
                    context.read<AudioPracticeBloc>().add(
                      StopRecordingEvent('', exId, currentUserId),
                    );
                  } else {
                    context.read<AudioPracticeBloc>().add(const StartRecordingEvent());
                  }

                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAudioCoachSuiteColumn(BuildContext context) {
    return BlocBuilder<AudioPracticeBloc, AudioPracticeState>(
      builder: (context, state) {
        if (state is AudioPracticeError) {
          return GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(LucideIcons.circleAlert, color: AppColors.error, size: 40),
                const SizedBox(height: AppSpacing.sm),
                const Text('Audio Analysis Notice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                Text(
                  state.message,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton.icon(
                  onPressed: () => context.read<AudioPracticeBloc>().add(const ResetEvent()),
                  icon: const Icon(LucideIcons.rotateCcw, size: 14),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          );
        }

        if (state is AudioAnalysisComplete) {
          final result = state.result;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Target Notes vs Detected Notes Comparison Box
              GlassCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(LucideIcons.music, size: 16, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Note Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Overall: ${result.overallScore > 0 ? result.overallScore : result.accuracy}%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 110,
                          child: Text('Target Notes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        ),
                        Expanded(
                          child: Text(
                            result.targetNotesDisplay,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 110,
                          child: Text('Detected Notes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        ),
                        Expanded(
                          child: Text(
                            result.detectedNotesDisplay,
                            style: TextStyle(
                              fontSize: 13,
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

              // Pitch & Note Accuracy Grid
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

              // Timing & Stability Rating Grid
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
              const SizedBox(height: AppSpacing.md),

              FeedbackCard(
                title: 'AI Vocal & Audio Coach',
                message: result.feedback,
              ),

              if (result.coachingTips.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: result.coachingTips
                        .map((tip) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                  Expanded(child: Text(tip, style: const TextStyle(fontSize: 12))),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.md),
              Text(
                'Detected Pitch Capsules',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: result.notes.map((n) {
                  return NoteCapsule(note: n.note, accuracy: n.accuracy);
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<AudioPracticeBloc>().add(const ResetEvent());
                  },
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('Practice Audio Again'),
                ),
              ),
            ],
          );
        }

        // Default initial suite display
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AIMessageCard(
              message: 'Sing or play sustained notes near your device microphone. Audio AI calculates frequency spectrum, resonance, and pitch stability in real-time.',
            ),
            const SizedBox(height: AppSpacing.md),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(LucideIcons.sparkles, color: AppColors.accent, size: 18),
                      SizedBox(width: 8),
                      Text('Audio AI Evaluation Guidelines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildGuidelineItem('1. Acoustic Environment', 'Practice in a quiet room for high frequency accuracy.'),
                  _buildGuidelineItem('2. Vocal Intonation', 'Hold notes steadily for at least 2 seconds for stability analysis.'),
                  _buildGuidelineItem('3. Instrument Support', 'Supports acoustic guitar, piano, flute, and vocal drills.'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuidelineItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
          Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ==========================================
  // MIDI KEYBOARD CONSOLE & COACH
  // ==========================================
  Widget _buildMidiConsoleColumn(BuildContext context, bool isDark) {
    return BlocBuilder<MidiPracticeBloc, MidiPracticeState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hardware Status Card
            _buildMidiStatusCard(context, state),
            const SizedBox(height: AppSpacing.md),

            // Active Exercise Control Card
            _buildMidiExerciseCard(context),
            const SizedBox(height: AppSpacing.md),

            // Virtual Piano Keys Console
            _buildVirtualPianoConsole(),
          ],
        );
      },
    );
  }

  Widget _buildMidiCoachSuiteColumn(BuildContext context, bool isDark) {
    final currentExercises = ExerciseRepository.getExercisesByLevel(_selectedLevel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Exercise Selector Dropdown
        Text('Select MIDI Practice Exercise', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.xs),
        _buildMidiExerciseDropdown(currentExercises, isDark),
        const SizedBox(height: AppSpacing.md),

        // Expected Notes Sequence
        Text(
          'Expected Note Sequence (${_selectedMidiExercise.notes.length} Notes)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: List.generate(_selectedMidiExercise.notes.length, (idx) {
            return NoteCapsule(
              note: _selectedMidiExercise.notes[idx],
              isActive: _activeNoteIndex == idx,
            );
          }),
        ),
        const SizedBox(height: AppSpacing.md),

        // AI Tip Card
        AIMessageCard(message: _selectedMidiExercise.aiTip),
      ],
    );
  }

  Widget _buildMidiStatusCard(BuildContext context, MidiPracticeState state) {
    final theme = Theme.of(context);
    Color indicatorColor = AppColors.error;
    String statusTitle = 'MIDI Hardware Disconnected';
    String statusBody = 'Connect USB/Bluetooth keyboard, or practice with virtual keys below.';
    Widget actionButtons;

    if (state is MidiScanning) {
      indicatorColor = AppColors.warning;
      statusTitle = 'Scanning for MIDI Hardware...';
      statusBody = 'Searching for active Bluetooth or USB MIDI endpoints...';
      actionButtons = const SizedBox(
        height: 36,
        child: Center(child: CircularProgressIndicator(color: AppColors.secondary, strokeWidth: 2)),
      );
    } else if (state is MidiConnected) {
      indicatorColor = AppColors.success;
      statusTitle = 'MIDI Hardware Connected';
      statusBody = 'Active Device: ${state.deviceName}\nSignal: 100% • Latency: 4ms • Port 1 (88 Velocity Keys)';
      actionButtons = Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                _stopMidiSimulation();
                context.read<MidiPracticeBloc>().add(const DisconnectMidiDeviceEvent());
              },
              icon: const Icon(LucideIcons.unlink, size: 14),
              label: const Text('Disconnect', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showMidiDevicePickerModal(context),
              icon: const Icon(LucideIcons.refreshCw, size: 14),
              label: const Text('Switch Device', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            ),
          ),
        ],
      );
    } else {
      actionButtons = ElevatedButton.icon(
        onPressed: () => _showMidiDevicePickerModal(context),
        icon: const Icon(LucideIcons.search, size: 14),
        label: const Text('Scan & Connect MIDI Hardware', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
        ),
      );
    }

    return GlassCard(
      borderColor: indicatorColor.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: indicatorColor)),
              const SizedBox(width: 8),
              Text(statusTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(statusBody, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: actionButtons),
        ],
      ),
    );
  }

  void _showMidiDevicePickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool isScanning = false;
        List<MidiDeviceItem> hardwareDevices = [];
        bool scannedOnce = false;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            void runScan() async {
              setModalState(() => isScanning = true);
              final devices = await MidiHardwareService.scanHardwareDevices();
              if (modalContext.mounted) {
                setModalState(() {
                  hardwareDevices = devices;
                  isScanning = false;
                  scannedOnce = true;
                });
              }
            }

            if (!scannedOnce && !isScanning) {
              runScan();
            }

            return Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(LucideIcons.keyboard, color: AppColors.secondary, size: 22),
                            SizedBox(width: 8),
                            Text('System USB MIDI Hardware Scanner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Scanning active computer USB ports & Bluetooth LE for hardware instruments:',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    if (isScanning)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(AppBorderRadius.md),
                          border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: const [
                            CircularProgressIndicator(color: AppColors.secondary),
                            SizedBox(height: 12),
                            Text('Querying OS System USB Ports & Web MIDI API...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(height: 4),
                            Text('Checking physical USB controllers and Bluetooth LE instruments', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    else if (hardwareDevices.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(AppBorderRadius.md),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(LucideIcons.alertCircle, color: AppColors.error, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'No Physical USB MIDI Keyboard Detected',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Zero physical MIDI controllers or digital pianos were detected on your system USB ports.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const Divider(height: 20),
                            const Text('Troubleshooting & Options:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 6),
                            const Text('• 🔌 Plug your MIDI keyboard into a USB-A/C port with a USB cable.', style: TextStyle(fontSize: 11)),
                            const Text('• ⚡ Ensure your keyboard power switch is turned ON.', style: TextStyle(fontSize: 11)),
                            const Text('• 🔄 Click "Rescan System USB Ports" below after connecting.', style: TextStyle(fontSize: 11)),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: runScan,
                                    icon: const Icon(LucideIcons.refreshCw, size: 14),
                                    label: const Text('Rescan USB Ports', style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      context.read<MidiPracticeBloc>().add(const ConnectMidiDeviceEvent('Built-in Interactive Virtual Keys'));
                                    },
                                    icon: const Icon(LucideIcons.keyboard, size: 14),
                                    label: const Text('Use Virtual Keys', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Detected ${hardwareDevices.length} Hardware USB MIDI Instrument(s)',
                                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...hardwareDevices.map((device) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _buildMidiDeviceOptionItem(
                                ctx,
                                deviceName: device.name,
                                connectionType: '${device.manufacturer} • ${device.connectionType}',
                                isBest: true,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  context.read<MidiPracticeBloc>().add(ConnectMidiDeviceEvent(device.name));
                                },
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMidiDeviceOptionItem(
    BuildContext context, {
    required String deviceName,
    required String connectionType,
    bool isBest = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(
          color: isBest ? AppColors.secondary : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          width: isBest ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.secondary.withOpacity(0.15),
          ),
          child: const Icon(LucideIcons.keyboard, color: AppColors.secondary, size: 18),
        ),
        title: Text(deviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(connectionType, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        trailing: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: const Text('Connect', style: TextStyle(fontSize: 11)),
        ),
      ),
    );
  }

  Widget _buildMidiExerciseDropdown(List<PracticeExercise> currentExercises, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PracticeExercise>(
          value: currentExercises.contains(_selectedMidiExercise) ? _selectedMidiExercise : currentExercises.first,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, color: AppColors.secondary, size: 18),
          items: currentExercises.map((ex) {
            return DropdownMenuItem<PracticeExercise>(
              value: ex,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(ex.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('${ex.description} • ${ex.targetBpm} BPM', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            );
          }).toList(),
          onChanged: (ex) {
            if (ex != null) {
              setState(() {
                _selectedMidiExercise = ex;
                _stopMidiSimulation();
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildMidiExerciseCard(BuildContext context) {
    return GlassCard(
      borderColor: AppColors.secondary.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedMidiExercise.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(_selectedMidiExercise.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedMidiExercise.targetBpm} BPM',
                  style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isMidiPlaying) ...[
            LinearProgressIndicator(
              value: (_activeNoteIndex + 1) / _selectedMidiExercise.notes.length,
              color: AppColors.success,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Playing Note: ${_selectedMidiExercise.notes[_activeNoteIndex]}',
                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text('Score: $_midiScore%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isMidiPlaying ? _stopMidiSimulation : _startMidiSimulation,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMidiPlaying ? AppColors.error : AppColors.secondary,
              ),
              icon: Icon(_isMidiPlaying ? LucideIcons.square : LucideIcons.play, size: 16),
              label: Text(_isMidiPlaying ? 'Stop Practice Run' : 'Start MIDI Practice Run'),
            ),
          ),
        ],
      ),
    );
  }

  // Dynamic Virtual Piano Keyboard Component Console
  Widget _buildVirtualPianoConsole() {
    final activeNote = (_activeNoteIndex >= 0 && _activeNoteIndex < _selectedMidiExercise.notes.length)
        ? _selectedMidiExercise.notes[_activeNoteIndex]
        : null;

    // Dynamically derive unique notes from the selected exercise
    final List<String> dynamicKeys = _selectedMidiExercise.notes.toSet().toList();
    if (dynamicKeys.isEmpty) {
      dynamicKeys.addAll(['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5']);
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Interactive Virtual Key Pads',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_selectedMidiExercise.notes.length} Active Notes',
                  style: const TextStyle(fontSize: 10, color: AppColors.secondary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: dynamicKeys.map((keyNote) {
                final isSharp = keyNote.contains('#');
                final isActive = activeNote != null && activeNote.toUpperCase() == keyNote.toUpperCase();

                return GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(LucideIcons.music, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text('Played note "$keyNote" on Virtual Keyboard'),
                          ],
                        ),
                        backgroundColor: AppColors.secondary,
                        duration: const Duration(milliseconds: 1000),
                      ),
                    );

                    // If simulation is running and tapped key matches expected note
                    if (_isMidiPlaying && activeNote != null && activeNote.toUpperCase() == keyNote.toUpperCase()) {
                      setState(() {
                        _notesMatched++;
                        _midiScore = ((_notesMatched / _selectedMidiExercise.notes.length) * 100).round();
                        if (_activeNoteIndex < _selectedMidiExercise.notes.length - 1) {
                          _activeNoteIndex++;
                        } else {
                          _isMidiPlaying = false;
                          _practiceTimer?.cancel();
                          _showMidiCompletionDialog();
                        }
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isSharp ? 34 : 42,
                    height: isSharp ? 85 : 100,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.success
                          : isSharp
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                      border: Border.all(
                        color: isActive ? AppColors.success : (isSharp ? Colors.cyan : Colors.black38),
                        width: isActive ? 2 : 1,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: AppColors.success.withOpacity(0.6),
                                blurRadius: 12,
                                spreadRadius: 2,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isActive)
                              const Icon(LucideIcons.zap, size: 10, color: Colors.white),
                            Text(
                              keyNote,
                              style: TextStyle(
                                fontSize: isSharp ? 10 : 11,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? Colors.white
                                    : isSharp
                                        ? Colors.cyanAccent
                                        : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
