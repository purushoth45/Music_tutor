import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/constants/theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../midi_practice/domain/models/exercise_model.dart';
import '../../../midi_practice/data/repositories/exercise_repository.dart';
import '../../data/datasources/trainer_datasource.dart';

class TrainerStudentsScreen extends StatefulWidget {
  const TrainerStudentsScreen({Key? key}) : super(key: key);

  @override
  State<TrainerStudentsScreen> createState() => _TrainerStudentsScreenState();
}

class _TrainerStudentsScreenState extends State<TrainerStudentsScreen> {
  final TrainerDataSource _dataSource = TrainerDataSource();
  List<RemoteTrainee> _allStudents = [];
  bool _isLoading = true;
  String? _errorMessage;

  SkillLevel? _filterLevel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final students = await _dataSource.getTrainees();
      setState(() {
        _allStudents = students;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showAssignExerciseDialog(RemoteTrainee student) {
    final exercises = ExerciseRepository.getAllExercises();
    PracticeExercise selectedExercise = exercises.first;
    final notesController = TextEditingController(text: 'Please practice this exercise before our next class.');
    bool isAssigning = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              title: Text('Assign Task to ${student.fullName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Practice Exercise', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<PracticeExercise>(
                      value: selectedExercise,
                      decoration: const InputDecoration(),
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
                    const Text('Trainer Instructions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'Custom trainer tips for the student...'),
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
                              traineeId: student.id,
                              exerciseId: selectedExercise.id,
                              notes: notesController.text.trim(),
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Assigned "${selectedExercise.title}" to ${student.fullName}!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            _fetchStudents();
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
    String? selectedTargetLevel = 'BEGINNER';
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
                                content: Text('Assigned "${selectedExercise.title}" to target group!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            _fetchStudents();
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
                      decoration: const InputDecoration(hintText: 'e.g. Emily Watson'),
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
                    const Text('Initial Assigned Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(hintText: '••••••••'),
                    ),
                    const SizedBox(height: 12),
                    const Text('Skill Level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                              const SnackBar(content: Text('Please enter name and email')),
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
                                content: Text('Student "${nameController.text}" registered in DB!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            _fetchStudents();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = theme.textTheme.headlineMedium?.color ?? Colors.white;

    final filteredStudents = _allStudents.where((student) {
      final matchesLevel = _filterLevel == null || student.skillLevel == _filterLevel;
      final query = _searchController.text.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          student.fullName.toLowerCase().contains(query) ||
          student.email.toLowerCase().contains(query);
      return matchesLevel && matchesSearch;
    }).toList();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Roster & Tasks 📋',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Manage Trainees',
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
                      onPressed: _fetchStudents,
                    ),
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

            // Level Bulk Assignment Banner Card
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '🎯 Common Level-Wise Assignment',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Assign shared practice exercises to all Beginner, Moderate, or Pro students.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showLevelWiseBulkAssignDialog,
                    icon: const Icon(LucideIcons.layers, size: 14),
                    label: const Text('Bulk Assign', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Search and Filter Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search student name or email...',
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                PopupMenuButton<SkillLevel?>(
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Icon(
                      LucideIcons.filter,
                      size: 18,
                      color: _filterLevel != null ? AppColors.primary : theme.iconTheme.color,
                    ),
                  ),
                  onSelected: (level) {
                    setState(() => _filterLevel = level);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: null,
                      child: Text('All Levels'),
                    ),
                    ...SkillLevel.values.map((lvl) {
                      return PopupMenuItem(
                        value: lvl,
                        child: Text(lvl.displayName),
                      );
                    }),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Student Roster Cards
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
                      Text('Error: $_errorMessage'),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _fetchStudents, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else if (filteredStudents.isEmpty)
              GlassCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(LucideIcons.users, size: 40, color: AppColors.textSecondary),
                        const SizedBox(height: 10),
                        Text(
                          _allStudents.isEmpty
                              ? 'No students found in MySQL database.'
                              : 'No students match your filter search.',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Column(
                children: filteredStudents.map((student) {
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
                                      radius: 20,
                                      backgroundColor: AppColors.primary.withOpacity(0.18),
                                      child: Text(
                                        student.fullName.isNotEmpty ? student.fullName.substring(0, 1).toUpperCase() : 'S',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student.fullName,
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            student.email,
                                            style: theme.textTheme.bodySmall,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  student.skillLevel.displayName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('Streak', '${student.streakDays} Days 🔥', AppColors.accent),
                              _buildStatItem('Avg Accuracy', '${student.averageAccuracy}%', AppColors.success),
                              _buildStatItem('Sessions', '${student.totalSessionsPlayed} Runs', AppColors.secondary),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Active Assigned Task Pill
                          if (student.currentAssignment != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.bookmark, size: 14, color: AppColors.secondary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Current Task: ${student.currentAssignment}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Action Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _showAssignExerciseDialog(student),
                              icon: const Icon(LucideIcons.send, size: 14),
                              label: const Text('Assign Practice Exercise', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
