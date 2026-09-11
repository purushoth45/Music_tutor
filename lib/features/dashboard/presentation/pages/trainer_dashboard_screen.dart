import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/constants/theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../midi_practice/domain/models/exercise_model.dart';
import '../../../midi_practice/data/repositories/exercise_repository.dart';
import '../../data/datasources/trainer_datasource.dart';

class TrainerDashboardScreen extends StatefulWidget {
  const TrainerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<TrainerDashboardScreen> createState() => _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState extends State<TrainerDashboardScreen> {
  final TrainerDataSource _dataSource = TrainerDataSource();
  List<RemoteTrainee> _trainees = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRealtimeData();
  }

  Future<void> _fetchRealtimeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final trainees = await _dataSource.getTrainees();
      setState(() {
        _trainees = trainees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showCreateTraineeDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController(text: 'student123');
    SkillLevel selectedLevel = SkillLevel.beginner;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              title: Row(
                children: const [
                  Icon(LucideIcons.userPlus, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Register New Student'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Full Student Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(hintText: 'e.g. Sarah Watson'),
                    ),
                    const SizedBox(height: 12),
                    const Text('Student Email Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(hintText: 'student@example.com'),
                    ),
                    const SizedBox(height: 12),
                    const Text('Student Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(hintText: '••••••••'),
                    ),
                    const SizedBox(height: 12),
                    const Text('Assigned Skill Level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<SkillLevel>(
                      value: selectedLevel,
                      items: SkillLevel.values.map((lvl) {
                        return DropdownMenuItem(
                          value: lvl,
                          child: Text(lvl.displayName, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedLevel = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty || emailController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill in name and email address')),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          try {
                            await _dataSource.createTrainee(
                              fullName: nameController.text.trim(),
                              email: emailController.text.trim(),
                              password: passwordController.text.trim(),
                              skillLevel: selectedLevel.name.toUpperCase(),
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Student "${nameController.text}" created in DB!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            _fetchRealtimeData();
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceAll('Exception: ', '')),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.check, size: 16),
                  label: const Text('Register Student'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAssignExerciseDialog(RemoteTrainee trainee) {
    final exercises = ExerciseRepository.getAllExercises();
    PracticeExercise selectedExercise = exercises.first;
    final notesController = TextEditingController(text: 'Please practice this lesson before our next class.');
    bool isAssigning = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              title: Text('Assign Task to ${trainee.fullName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Practice Exercise', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<PracticeExercise>(
                      value: selectedExercise,
                      items: exercises.map((ex) {
                        return DropdownMenuItem(
                          value: ex,
                          child: Text('${ex.title} (${ex.level.displayName})', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedExercise = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Trainer Notes / Instructions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'Custom instructions for the student...'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isAssigning ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isAssigning
                      ? null
                      : () async {
                          setDialogState(() => isAssigning = true);
                          try {
                            await _dataSource.assignExercise(
                              traineeId: trainee.id,
                              exerciseId: selectedExercise.id,
                              notes: notesController.text.trim(),
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Assigned "${selectedExercise.title}" to ${trainee.fullName}!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            _fetchRealtimeData();
                          } catch (e) {
                            setDialogState(() => isAssigning = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceAll('Exception: ', '')),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  icon: isAssigning
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.send, size: 16),
                  label: const Text('Assign Task'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLevelWiseBulkAssignDialog() {
    final exercises = ExerciseRepository.getAllExercises();
    PracticeExercise selectedExercise = exercises.first;
    String? selectedTargetLevel = 'BEGINNER'; // 'ALL', 'BEGINNER', 'MODERATE', 'PRO'
    final notesController = TextEditingController(text: 'Common level lesson assigned by Instructor.');
    bool isAssigning = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              title: Row(
                children: const [
                  Icon(LucideIcons.target, color: AppColors.secondary, size: 20),
                  SizedBox(width: 8),
                  Text('Level-Wise Bulk Assignment'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Target Student Group (Level)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: selectedTargetLevel,
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Students (Everyone)', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'BEGINNER', child: Text('Beginner Level Students', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'MODERATE', child: Text('Moderate Level Students', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'PRO', child: Text('Pro / Advanced Level Students', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedTargetLevel = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Select Exercise / Lesson', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<PracticeExercise>(
                      value: selectedExercise,
                      items: exercises.map((ex) {
                        return DropdownMenuItem(
                          value: ex,
                          child: Text('${ex.title} (${ex.level.displayName})', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedExercise = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Group Instructions / Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'Common level guidance...'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isAssigning ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isAssigning
                      ? null
                      : () async {
                          setDialogState(() => isAssigning = true);
                          try {
                            final filter = selectedTargetLevel == 'ALL' ? null : selectedTargetLevel;
                            await _dataSource.assignExerciseBulk(
                              skillLevel: filter,
                              exerciseId: selectedExercise.id,
                              notes: notesController.text.trim(),
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Assigned "${selectedExercise.title}" to level-matched students!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            _fetchRealtimeData();
                          } catch (e) {
                            setDialogState(() => isAssigning = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceAll('Exception: ', '')),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  icon: isAssigning
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.layers, size: 16),
                  label: const Text('Assign to Group'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = theme.textTheme.headlineMedium?.color ?? Colors.white;

    final int totalCount = _trainees.length;
    final double avgAccuracy = totalCount > 0
        ? _trainees.fold<int>(0, (sum, item) => sum + item.averageAccuracy) / totalCount
        : 0.0;
    final int activeTasksCount = _trainees.where((t) => t.currentAssignment != null).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructor Dashboard 👨‍🏫',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Realtime Roster',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    tooltip: 'Refresh Roster',
                    onPressed: _fetchRealtimeData,
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: _showCreateTraineeDialog,
                    icon: const Icon(LucideIcons.userPlus, size: 15),
                    label: const Text('Add Student'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Overview Stats
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.users, color: AppColors.primary, size: 22),
                      const SizedBox(height: 4),
                      Text('$totalCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Text('Total Students', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.target, color: AppColors.success, size: 22),
                      const SizedBox(height: 4),
                      Text('${avgAccuracy.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Text('Avg Accuracy', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.bookOpen, color: AppColors.secondary, size: 22),
                      const SizedBox(height: 4),
                      Text('$activeTasksCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Text('Active Tasks', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Level Bulk Assignment Quick Action Card
          GlassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '🎯 Level-Wise Task Assignment',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Assign common lessons to Beginner, Moderate, or Pro students in 1 click.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showLevelWiseBulkAssignDialog,
                  icon: const Icon(LucideIcons.layers, size: 14),
                  label: const Text('Bulk Assign', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Students Roster Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Student Roster ($totalCount)',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _showCreateTraineeDialog,
                icon: const Icon(LucideIcons.plus, size: 14),
                label: const Text('New Student'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Body Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(30.0),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_errorMessage != null)
            GlassCard(
              child: Center(
                child: Column(
                  children: [
                    const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 30),
                    const SizedBox(height: 8),
                    Text('Failed to load roster: $_errorMessage', textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: _fetchRealtimeData, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else if (_trainees.isEmpty)
            GlassCard(
              child: Center(
                child: Column(
                  children: [
                    const Icon(LucideIcons.users, size: 36, color: AppColors.textSecondary),
                    const SizedBox(height: 8),
                    const Text('No students registered yet in MySQL database.'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _showCreateTraineeDialog,
                      icon: const Icon(LucideIcons.userPlus, size: 16),
                      label: const Text('Register First Student'),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _trainees.map((trainee) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primary.withOpacity(0.2),
                                    child: Text(
                                      trainee.fullName.isNotEmpty ? trainee.fullName.substring(0, 1).toUpperCase() : 'S',
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trainee.fullName,
                                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${trainee.email} • ${trainee.skillLevel.displayName}',
                                          style: theme.textTheme.bodySmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showAssignExerciseDialog(trainee),
                              icon: const Icon(LucideIcons.send, size: 14),
                              label: const Text('Assign Task', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Streak', '${trainee.streakDays} Days 🔥', AppColors.accent),
                            _buildStatItem('Accuracy', '${trainee.averageAccuracy}%', AppColors.success),
                            _buildStatItem('Sessions', '${trainee.totalSessionsPlayed} Runs', AppColors.secondary),
                          ],
                        ),
                        if (trainee.currentAssignment != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.bookmark, size: 14, color: AppColors.secondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Active Task: ${trainee.currentAssignment}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
