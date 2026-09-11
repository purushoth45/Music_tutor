import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/constants/theme.dart';
import '../../../../core/api_client.dart';
import '../../../../core/user_session.dart';
import '../../presentation/bloc/profile_bloc.dart';
import '../../presentation/bloc/profile_event.dart';
import '../../presentation/bloc/profile_state.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../../dashboard/data/datasources/trainer_datasource.dart';
import '../../../midi_practice/domain/models/exercise_model.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../widgets/profile_header.dart';
import '../widgets/stats_grid.dart';
import '../widgets/session_history_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TrainerDataSource _trainerDataSource = TrainerDataSource();
  List<RemoteTrainee> _trainees = [];
  bool _isLoadingTrainees = false;
  String? _selectedAvatarUrl;

  final List<String> _avatarPresets = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&auto=format&fit=crop&q=80',
  ];

  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(const LoadProfileEvent());
    _fetchTrainerData();
  }

  Future<void> _fetchTrainerData() async {
    if (!mounted) return;
    setState(() => _isLoadingTrainees = true);
    try {
      final trainees = await _trainerDataSource.getTrainees();
      if (!mounted) return;
      setState(() {
        _trainees = trainees;
        _isLoadingTrainees = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingTrainees = false);
    }
  }

  void _showAvatarPicker() {
    final customUrlController = TextEditingController(text: _selectedAvatarUrl ?? '');

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Row(
            children: const [
              Icon(LucideIcons.camera, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Change Profile Photo'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose Instructor Preset Avatar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _avatarPresets.map((url) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAvatarUrl = url;
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile photo updated successfully!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedAvatarUrl == url ? AppColors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: Image.network(url, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Or Enter Custom Photo URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: customUrlController,
                  decoration: const InputDecoration(
                    hintText: 'https://example.com/avatar.jpg',
                    prefixIcon: Icon(LucideIcons.link, size: 16),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final url = customUrlController.text.trim();
                if (url.isNotEmpty) {
                  setState(() {
                    _selectedAvatarUrl = url;
                  });
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile photo updated!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Save Photo'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isTrainer = (authState is AuthAuthenticated && authState.user.isTrainer) || UserSession.isTrainer;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTrainer ? 'Instructor Profile' : 'My Profile'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            tooltip: 'Refresh',
            onPressed: () {
              context.read<ProfileBloc>().add(const LoadProfileEvent());
              _fetchTrainerData();
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.logOut),
            tooltip: 'Sign Out',
            onPressed: () {
              UserSession.currentUser = null;
              context.read<AuthBloc>().add(const LogoutEvent());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out successfully!'),
                  backgroundColor: AppColors.primary,
                ),
              );
              context.go('/login');
            },
          ),
        ],
      ),
      body: isTrainer ? _buildTrainerProfile(context) : _buildTraineeProfile(context),
    );
  }

  Widget _buildTrainerProfile(BuildContext context) {
    final theme = Theme.of(context);
    final user = UserSession.currentUser;

    final String displayName = user?.name ?? 'Prof. Alexander Vance';
    final String displayEmail = user?.email ?? 'trainer@musictutor.ai';

    final int totalTrainees = _trainees.length;
    final double avgAccuracy = totalTrainees > 0
        ? _trainees.fold<int>(0, (sum, t) => sum + t.averageAccuracy) / totalTrainees
        : 0.0;
    final int activeAssignmentsCount = _trainees.where((t) => t.currentAssignment != null).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructor Header with Photo Picker
          ProfileHeader(
            name: displayName,
            level: 'Master Instructor • Piano & Theory',
            avatarUrl: _selectedAvatarUrl,
            onAvatarTap: _showAvatarPicker,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Realtime Class Performance Stats Cards
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.users, color: AppColors.primary, size: 22),
                      const SizedBox(height: 4),
                      Text('$totalTrainees', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Text('Trainees', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
                      const Text('Class Avg', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
                      const Icon(LucideIcons.bookOpen, color: AppColors.accent, size: 22),
                      const SizedBox(height: 4),
                      Text('$activeAssignmentsCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Text('Active Tasks', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Instructor Credentials & Details
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.award, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Instructor Credentials',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '• Instructor Account: $displayEmail',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '• Certified Senior Music Pedagogue (RCM / ABRSM)',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '• Specialization: Scale Evaluation & MIDI Practice Tracking',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Recent Realtime Instructor Actions & Student Activity
          Text(
            'Live Student Activity',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),

          if (_isLoadingTrainees)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_trainees.isEmpty)
            GlassCard(
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No student activity logged yet.'),
                ),
              ),
            )
          else
            Column(
              children: _trainees.map((student) {
                final String taskTitle = student.currentAssignment != null
                    ? 'Assigned "${student.currentAssignment}" to ${student.fullName}'
                    : 'Managed Student: ${student.fullName} (${student.skillLevel.displayName})';
                final String taskType = student.currentAssignment != null ? 'Task' : 'Student';
                final String scoreBadge = student.currentAssignment != null ? 'Assigned' : 'Active';

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: SessionHistoryCard(
                    title: taskTitle,
                    date: 'MySQL Record #${student.id}',
                    score: scoreBadge,
                    type: taskType,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  List<dynamic> _realTraineeSessions = [];
  bool _isLoadingHistory = false;

  Future<void> _fetchTraineeHistory(String userIdStr) async {
    final int userId = int.tryParse(userIdStr) ?? 1;
    setState(() => _isLoadingHistory = true);
    try {
      final response = await ApiClient().get('/practice/history?user_id=$userId');
      if (!mounted) return;
      if (response is List) {
        setState(() {
          _realTraineeSessions = response;
          _isLoadingHistory = false;
        });
      } else {
        setState(() => _isLoadingHistory = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
    }
  }

  Widget _buildTraineeProfile(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        if (state is ProfileLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.secondary),
          );
        } else if (state is ProfileLoaded) {
          final user = state.user;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header with image picker
                ProfileHeader(
                  name: user.name,
                  level: user.level,
                  avatarUrl: _selectedAvatarUrl,
                  onAvatarTap: _showAvatarPicker,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Stats Row layout
                StatsGrid(
                  badgeCount: user.badges.length,
                  averageAccuracy: user.averageAccuracy,
                  streakDays: user.streak,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Practice Session History
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Sessions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                      onPressed: () => _fetchTraineeHistory(user.id),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                if (_isLoadingHistory)
                  const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: AppColors.secondary)))
                else if (_realTraineeSessions.isEmpty)
                  GlassCard(
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No practice runs logged yet. Start a practice session!'),
                      ),
                    ),
                  )
                else
                  Column(
                    children: _realTraineeSessions.map((session) {
                      final acc = session['accuracy_score'] ?? 0;
                      final type = session['session_type']?.toString() ?? 'MIDI';
                      final created = session['created_at']?.toString().split('T').first ?? 'Recent';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: SessionHistoryCard(
                          title: '$type Practice Session',
                          date: created,
                          score: '$acc%',
                          type: type,
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        } else {
          return const Center(
            child: Text(
              'Failed to load profile details',
              style: TextStyle(color: Colors.white),
            ),
          );
        }
      },
    );
  }
}
