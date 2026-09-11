import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/constants/theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../domain/models/exercise_model.dart';
import '../bloc/midi_practice_bloc.dart';
import '../bloc/midi_practice_event.dart';
import '../bloc/midi_practice_state.dart';
import '../../../audio_practice/presentation/widgets/note_capsule.dart';
import '../../../dashboard/presentation/widgets/ai_message_card.dart';

class MidiPracticeScreen extends StatefulWidget {
  const MidiPracticeScreen({Key? key}) : super(key: key);

  @override
  State<MidiPracticeScreen> createState() => _MidiPracticeScreenState();
}

class _MidiPracticeScreenState extends State<MidiPracticeScreen> {
  SkillLevel _selectedLevel = SkillLevel.beginner;
  late PracticeExercise _selectedExercise;

  // Interactive Practice Player State
  bool _isPlaying = false;
  int _activeNoteIndex = -1;
  Timer? _practiceTimer;
  int _score = 0;
  int _notesMatched = 0;

  @override
  void initState() {
    super.initState();
    _selectedExercise = ExerciseRepository.getExercisesByLevel(_selectedLevel).first;
  }

  @override
  void dispose() {
    _practiceTimer?.cancel();
    super.dispose();
  }

  void _onLevelChanged(SkillLevel level) {
    setState(() {
      _selectedLevel = level;
      final exercises = ExerciseRepository.getExercisesByLevel(level);
      _selectedExercise = exercises.first;
      _stopExerciseSimulation();
    });
  }

  void _onExerciseChanged(PracticeExercise exercise) {
    setState(() {
      _selectedExercise = exercise;
      _stopExerciseSimulation();
    });
  }

  void _startExerciseSimulation() {
    _stopExerciseSimulation();
    setState(() {
      _isPlaying = true;
      _activeNoteIndex = 0;
      _score = 0;
      _notesMatched = 0;
    });

    final intervalMs = (60000 / _selectedExercise.targetBpm).round();

    _practiceTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) return;

      setState(() {
        _notesMatched++;
        _score = ((_notesMatched / _selectedExercise.notes.length) * 100).round();

        if (_activeNoteIndex < _selectedExercise.notes.length - 1) {
          _activeNoteIndex++;
        } else {
          _isPlaying = false;
          timer.cancel();
          _showCompletionDialog();
        }
      });
    });
  }

  void _stopExerciseSimulation() {
    _practiceTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _activeNoteIndex = -1;
    });
  }

  void _showCompletionDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Row(
            children: [
              const Icon(LucideIcons.award, color: AppColors.warning, size: 24),
              const SizedBox(width: 8),
              Text('Exercise Complete!', style: theme.textTheme.titleLarge),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Great job practicing "${_selectedExercise.title}"!'),
              const SizedBox(height: 12),
              Text('• Level: ${_selectedLevel.displayName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('• Target BPM: ${_selectedExercise.targetBpm}'),
              Text('• Accuracy Score: $_score%', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
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
    final currentExercises = ExerciseRepository.getExercisesByLevel(_selectedLevel);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () {
            context.go('/dashboard');
          },
        ),
        title: const Text('MIDI Keyboard Practice'),
      ),
      body: BlocBuilder<MidiPracticeBloc, MidiPracticeState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. MIDI Connection Status Card
                _buildMidiStatusCard(context, state),
                const SizedBox(height: AppSpacing.lg),

                // 2. Skill Level Selector Tabs
                Text(
                  'Select Skill Level',
                  style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildLevelSelector(),
                const SizedBox(height: AppSpacing.lg),

                // 3. Exercise Selection List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Exercises',
                      style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '${currentExercises.length} Lessons',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildExerciseDropdown(currentExercises),
                const SizedBox(height: AppSpacing.lg),

                // 4. Selected Exercise Player Card
                _buildExerciseCard(context, state),
                const SizedBox(height: AppSpacing.lg),

                // 5. Expected Notes Sequence Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Expected Notes Sequence',
                      style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '${_selectedExercise.notes.length} Notes',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: List.generate(_selectedExercise.notes.length, (idx) {
                    return NoteCapsule(
                      note: _selectedExercise.notes[idx],
                      isActive: _activeNoteIndex == idx,
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 6. Dynamic AI Coach Advice
                AIMessageCard(
                  message: _selectedExercise.aiTip,
                ),
              ],
            ),
          );
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
              onTap: () => _onLevelChanged(level),
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

  Widget _buildExerciseDropdown(List<PracticeExercise> currentExercises) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PracticeExercise>(
          value: currentExercises.contains(_selectedExercise)
              ? _selectedExercise
              : currentExercises.first,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.surface : Colors.white,
          icon: const Icon(LucideIcons.chevronDown, color: AppColors.secondary),
          items: currentExercises.map((exercise) {
            return DropdownMenuItem<PracticeExercise>(
              value: exercise,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    exercise.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${exercise.description} • ${exercise.targetBpm} BPM',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (exercise) {
            if (exercise != null) {
              _onExerciseChanged(exercise);
            }
          },
        ),
      ),
    );
  }

  Widget _buildMidiStatusCard(BuildContext context, MidiPracticeState state) {
    final theme = Theme.of(context);
    Color indicatorColor = AppColors.error;
    String statusTitle = 'MIDI Disconnected';
    String statusBody = 'Connect a USB/Bluetooth keyboard, or start interactive practice below.';
    Widget actionButton;

    if (state is MidiScanning) {
      indicatorColor = AppColors.warning;
      statusTitle = 'Scanning for MIDI devices...';
      statusBody = 'Searching for active Bluetooth or USB MIDI hardware endpoints...';
      actionButton = const SizedBox(
        height: 44,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
      );
    } else if (state is MidiConnected) {
      indicatorColor = AppColors.success;
      statusTitle = 'MIDI Connected';
      statusBody = 'Active Device: ${state.deviceName}';
      actionButton = OutlinedButton.icon(
        onPressed: () {
          _stopExerciseSimulation();
          context.read<MidiPracticeBloc>().add(const DisconnectMidiDeviceEvent());
        },
        icon: const Icon(LucideIcons.unlink, size: 18),
        label: const Text('Disconnect Device'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      );
    } else {
      actionButton = ElevatedButton.icon(
        onPressed: () {
          context.read<MidiPracticeBloc>().add(const ScanMidiDevicesEvent());
        },
        icon: const Icon(LucideIcons.search, size: 18),
        label: const Text('Scan for MIDI Keyboards'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 10),
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
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: indicatorColor,
                  boxShadow: [
                    BoxShadow(
                      color: indicatorColor.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                statusTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            statusBody,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: actionButton,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(BuildContext context, MidiPracticeState state) {
    final theme = Theme.of(context);

    return GlassCard(
      borderColor: AppColors.primary.withOpacity(0.3),
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
                    Text(
                      _selectedExercise.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      _selectedExercise.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedExercise.targetBpm} BPM',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Realtime Match Progress Indicator
          if (_isPlaying) ...[
            LinearProgressIndicator(
              value: (_activeNoteIndex + 1) / _selectedExercise.notes.length,
              backgroundColor: theme.brightness == Brightness.dark
                  ? Colors.white10
                  : const Color(0xFFE2E8F0),
              color: AppColors.success,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Playing Note: ${_selectedExercise.notes[_activeNoteIndex]}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Score: $_score%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isPlaying ? _stopExerciseSimulation : _startExerciseSimulation,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isPlaying ? AppColors.error : AppColors.primary,
              ),
              icon: Icon(_isPlaying ? LucideIcons.square : LucideIcons.play, size: 18),
              label: Text(_isPlaying ? 'Stop Practice' : 'Start Interactive Practice'),
            ),
          ),
        ],
      ),
    );
  }
}
