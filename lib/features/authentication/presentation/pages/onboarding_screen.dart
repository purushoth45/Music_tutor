import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/constants/theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/gradient_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlideData> _slides = [
    OnboardingSlideData(
      icon: LucideIcons.mic,
      title: 'AI Audio Coach',
      description: 'Record your singing or playing and get instant, pitch-by-pitch accuracy and tone stability analysis from our AI model.',
      gradientColors: [AppColors.primary, AppColors.accent],
    ),
    OnboardingSlideData(
      icon: LucideIcons.keyboard,
      title: 'MIDI Integration',
      description: 'Connect your MIDI keyboard or digital piano via USB-C or Bluetooth to perform structured training with real-time feedback.',
      gradientColors: [AppColors.secondary, AppColors.primary],
    ),
    OnboardingSlideData(
      icon: LucideIcons.trophy,
      title: 'Achieve & Progress',
      description: 'Unlock milestone badges, track practice consistency streaks, and view detailed session history profiles as you improve.',
      gradientColors: [AppColors.accent, AppColors.secondary],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPressed() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F0F2E),
              Color(0xFF0A0A1E),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Column(
              children: [
                // Top skip action
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (int page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return _buildSlide(slide);
                    },
                  ),
                ),
                // Indicators & Action Button
                Column(
                  children: [
                    // Smooth page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _currentPage == index
                                ? AppColors.secondary
                                : Colors.white.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // Action button
                    GradientButton(
                      text: _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                      onPressed: _onNextPressed,
                      colors: _slides[_currentPage].gradientColors,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(OnboardingSlideData slide) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Graphic illustration container
        Container(
          height: 220,
          width: 220,
          alignment: Alignment.center,
          child: GlassCard(
            borderRadius: 110, // circle
            padding: const EdgeInsets.all(AppSpacing.xl),
            borderColor: slide.gradientColors[0].withOpacity(0.25),
            gradientColors: [
              slide.gradientColors[0].withOpacity(0.15),
              slide.gradientColors[1].withOpacity(0.05),
            ],
            child: Center(
              child: Icon(
                slide.icon,
                size: 80,
                color: Colors.white,
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scaleXY(begin: 0.9, end: 1.1, duration: 1800.ms, curve: Curves.easeInOut)
                  .custom(
                    builder: (context, value, child) {
                      return Transform.rotate(
                        angle: value * 0.15 - 0.075,
                        child: child,
                      );
                    },
                  ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        // Title Text
        Text(
          slide.title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        // Description Text
        Text(
          slide.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class OnboardingSlideData {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradientColors;

  OnboardingSlideData({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradientColors,
  });
}
