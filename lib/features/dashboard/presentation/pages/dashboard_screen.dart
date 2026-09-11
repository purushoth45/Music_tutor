import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/constants/theme.dart';
import '../../../../core/user_session.dart';
import '../widgets/ai_message_card.dart';
import '../widgets/practice_mode_card.dart';
import '../../../audio_practice/presentation/widgets/score_card.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/datasources/dashboard_datasource.dart';
import 'trainer_dashboard_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardDataSource _dataSource = DashboardDataSource();
  RemoteDashboardSummary? _summary;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    final authState = context.read<AuthBloc>().state;
    int? userId;
    if (authState is AuthAuthenticated) {
      userId = int.tryParse(authState.user.id);
    } else if (UserSession.currentUser != null) {
      userId = int.tryParse(UserSession.currentUser!.id);
    }

    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No active session. Please log in.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary = await _dataSource.getSummary(userId);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isTrainer = (state is AuthAuthenticated && state.user.isTrainer) || UserSession.isTrainer;

        if (isTrainer) {
          return const Scaffold(
            body: SafeArea(
              bottom: false,
              child: TrainerDashboardScreen(),
            ),
          );
        }

        final userName = (state is AuthAuthenticated && state.user.name.isNotEmpty)
            ? state.user.name
            : (UserSession.currentUser?.name ?? _summary?.fullName ?? _summary?.username ?? 'Learner');

        final initials = userName.isNotEmpty
            ? (userName.contains(' ')
                ? '${userName.split(' ').first[0]}${userName.split(' ').last[0]}'.toUpperCase()
                : userName.substring(0, 1).toUpperCase())
            : 'ML';

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _fetchSummary,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome header banner
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            Text(
                              '$userName 👋',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => context.go('/profile'),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.accent],
                              ),
                            ),
                            child: Center(
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.transparent,
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Realtime Trainer Assigned Task Banner
                    GlassCard(
                      borderColor: AppColors.secondary.withOpacity(0.3),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.secondary.withOpacity(0.15),
                            ),
                            child: const Icon(LucideIcons.userCheck, color: AppColors.secondary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Instructor Assigned Task',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _summary?.currentAssignment != null
                                      ? 'Your Instructor assigned "${_summary!.currentAssignment}". Practice now!'
                                      : 'No active task assigned. Start a practice run below!',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // AI Practice Coach Advice
                    AIMessageCard(
                      message: _summary?.aiCoachMessage ??
                          'You\'re making great progress! Try practicing with the MIDI mode today to sync with a physical keyboard.',
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Interactive Practice Modes Header
                    Text(
                      'Practice Modes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Mode Grid (MIDI vs Audio AI)
                    Row(
                      children: [
                        Expanded(
                          child: PracticeModeCard(
                            icon: LucideIcons.keyboard,
                            title: 'MIDI Practice',
                            subtitle: 'Beginner • Moderate • Pro',
                            accentColor: AppColors.primary,
                            onTap: () {
                              context.go('/midi-practice');
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: PracticeModeCard(
                            icon: LucideIcons.mic,
                            title: 'Audio AI',
                            subtitle: 'Beginner • Moderate • Pro',
                            accentColor: AppColors.secondary,
                            onTap: () {
                              context.go('/audio-practice');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Realtime Progress Stats Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Progress',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.refreshCw, size: 16),
                          onPressed: _fetchSummary,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Realtime Score Cards
                    Row(
                      children: [
                        Expanded(
                          child: ScoreCard(
                            label: 'Avg. Accuracy',
                            value: _isLoading ? '...' : '${_summary?.averageAccuracy ?? 0}%',
                            icon: LucideIcons.target,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ScoreCard(
                            label: 'Sessions Played',
                            value: _isLoading ? '...' : '${_summary?.totalSessionsPlayed ?? 0}',
                            icon: LucideIcons.history,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    ScoreCard(
                      label: 'Current Daily Streak',
                      value: _isLoading ? '...' : '${_summary?.streakDays ?? 0} Days 🔥',
                      icon: LucideIcons.flame,
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
