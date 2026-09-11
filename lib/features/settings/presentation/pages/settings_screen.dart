import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/constants/theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/themes/theme_controller.dart';
import '../../../midi_practice/domain/models/exercise_model.dart';

class AccentPalette {
  final String name;
  final Color primary;
  final Color secondary;

  const AccentPalette({
    required this.name,
    required this.primary,
    required this.secondary,
  });
}

class ThemeOption {
  final String label;
  final ThemeMode mode;

  const ThemeOption({
    required this.label,
    required this.mode,
  });
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<AccentPalette> _accentPalettes = [
    AccentPalette(
      name: 'Neon Purple',
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFF06B6D4),
    ),
    AccentPalette(
      name: 'Royal Amber',
      primary: Color(0xFFF59E0B),
      secondary: Color(0xFFEF4444),
    ),
    AccentPalette(
      name: 'Emerald Synth',
      primary: Color(0xFF10B981),
      secondary: Color(0xFF3B82F6),
    ),
    AccentPalette(
      name: 'Electric Sapphire',
      primary: Color(0xFF3B82F6),
      secondary: Color(0xFFEC4899),
    ),
  ];

  // Music Tutor Project Settings
  SkillLevel _defaultSkillLevel = SkillLevel.beginner;
  String _tuningStandard = 'A4 = 440 Hz (Standard)';
  bool _countInBeats = true;
  bool _metronomeClick = true;

  // MIDI Hardware & Audio Calibration Settings
  bool _autoConnectMidi = true;
  String _latencyProfile = 'Low Latency (16ms)';
  bool _audioFeedback = true;
  double _noiseCancellation = 0.75;
  double _micGain = 0.8;

  // Notifications & Preferences
  bool _dailyPracticeReminders = true;
  bool _detailedAiTips = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColorIdx = themeController.selectedPaletteIndex;
    final safeIndex = (selectedColorIdx >= 0 && selectedColorIdx < _accentPalettes.length)
        ? selectedColorIdx
        : 0;
    final activePalette = _accentPalettes[safeIndex];
    final primaryColor = activePalette.primary;
    final secondaryColor = activePalette.secondary;

    final sectionTitleStyle = TextStyle(
      color: theme.colorScheme.primary,
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Preferences'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎨 1. APPEARANCE & THEME
            _buildSectionHeader('Appearance & Styling', sectionTitleStyle),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme Mode',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Choose your preferred visual theme across the app',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildThemeModeSelector(primaryColor),
                  const Divider(height: 24),
                  Text(
                    'Accent Color Palette',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Customize app glow effects and primary highlights',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildColorPaletteSelector(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 🎵 2. MUSIC TUTOR PRACTICE PREFERENCES
            _buildSectionHeader('Music Practice Preferences', sectionTitleStyle),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text('Default Skill Level', style: theme.textTheme.titleMedium),
                    subtitle: Text('Currently set to: ${_defaultSkillLevel.displayName}', style: theme.textTheme.bodyMedium),
                    trailing: Icon(LucideIcons.chevronRight, color: theme.textTheme.bodyMedium?.color, size: 16),
                    contentPadding: EdgeInsets.zero,
                    onTap: _showSkillLevelDialog,
                  ),
                  const Divider(),
                  ListTile(
                    title: Text('Target Pitch Tuning Standard', style: theme.textTheme.titleMedium),
                    subtitle: Text(_tuningStandard, style: theme.textTheme.bodyMedium),
                    trailing: Icon(LucideIcons.chevronRight, color: theme.textTheme.bodyMedium?.color, size: 16),
                    contentPadding: EdgeInsets.zero,
                    onTap: _showTuningDialog,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text('4-Beat Metronome Count-In', style: theme.textTheme.titleMedium),
                    subtitle: Text('Play 4 prep clicks before starting scale exercises', style: theme.textTheme.bodyMedium),
                    value: _countInBeats,
                    onChanged: (val) => setState(() => _countInBeats = val),
                    activeThumbColor: primaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text('Audio Metronome Click', style: theme.textTheme.titleMedium),
                    subtitle: Text('Enable rhythmic click during practice runs', style: theme.textTheme.bodyMedium),
                    value: _metronomeClick,
                    onChanged: (val) => setState(() => _metronomeClick = val),
                    activeThumbColor: primaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 🎹 3. MIDI HARDWARE SETTINGS
            _buildSectionHeader('MIDI Keyboard Hardware', sectionTitleStyle),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Auto-connect MIDI Keyboards', style: theme.textTheme.titleMedium),
                    subtitle: Text('Automatically detect and pair USB/Bluetooth MIDI hardware', style: theme.textTheme.bodyMedium),
                    value: _autoConnectMidi,
                    onChanged: (bool value) {
                      setState(() {
                        _autoConnectMidi = value;
                      });
                    },
                    activeThumbColor: primaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  ListTile(
                    title: Text('Buffer Latency Profile', style: theme.textTheme.titleMedium),
                    subtitle: Text('Current: $_latencyProfile', style: theme.textTheme.bodyMedium),
                    trailing: Icon(LucideIcons.chevronRight, color: theme.textTheme.bodyMedium?.color, size: 16),
                    contentPadding: EdgeInsets.zero,
                    onTap: _showLatencyDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 🎙️ 4. AUDIO AI CALIBRATION
            _buildSectionHeader('Audio AI & Microphone Calibration', sectionTitleStyle),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: Text('Speech & Synthesized Pitch Prompts', style: theme.textTheme.titleMedium),
                    subtitle: Text('Hear reference pitch audio when practicing vocal scales', style: theme.textTheme.bodyMedium),
                    value: _audioFeedback,
                    onChanged: (bool value) {
                      setState(() {
                        _audioFeedback = value;
                      });
                    },
                    activeThumbColor: secondaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Noise Cancellation Level', style: theme.textTheme.titleMedium),
                      Text(
                        '${(_noiseCancellation * 100).toInt()}%',
                        style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    value: _noiseCancellation,
                    activeColor: secondaryColor,
                    onChanged: (double val) {
                      setState(() {
                        _noiseCancellation = val;
                      });
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Microphone Input Gain', style: theme.textTheme.titleMedium),
                      Text(
                        '${(_micGain * 10).toInt()}/10',
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    value: _micGain,
                    activeColor: primaryColor,
                    onChanged: (double val) {
                      setState(() {
                        _micGain = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 🤖 5. AI COACH & NOTIFICATIONS
            _buildSectionHeader('AI Coach & Notifications', sectionTitleStyle),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Daily Practice Reminders', style: theme.textTheme.titleMedium),
                    subtitle: Text('Receive gentle coaching alerts to keep your practice streak active', style: theme.textTheme.bodyMedium),
                    value: _dailyPracticeReminders,
                    onChanged: (val) => setState(() => _dailyPracticeReminders = val),
                    activeThumbColor: primaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text('Detailed AI Feedback Analysis', style: theme.textTheme.titleMedium),
                    subtitle: Text('Show microtonal pitch breakdown and articulation details', style: theme.textTheme.bodyMedium),
                    value: _detailedAiTips,
                    onChanged: (val) => setState(() => _detailedAiTips = val),
                    activeThumbColor: primaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 🛠️ 6. DATA & SYSTEM
            _buildSectionHeader('System & Data Management', sectionTitleStyle),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.trash2, color: AppColors.error, size: 20),
                    title: Text('Clear Cached Practice Audio', style: theme.textTheme.titleMedium),
                    subtitle: Text('Frees up local storage from past audio recordings', style: theme.textTheme.bodyMedium),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cached audio recordings cleared successfully!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(LucideIcons.helpCircle, color: secondaryColor, size: 20),
                    title: Text('Help Centre & Tutor Guide', style: theme.textTheme.titleMedium),
                    trailing: Icon(LucideIcons.chevronRight, color: theme.textTheme.bodyMedium?.color, size: 16),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(LucideIcons.info, color: primaryColor, size: 20),
                    title: Text('Music Tutor Version', style: theme.textTheme.titleMedium),
                    trailing: Text('v1.2.0 Pro', style: theme.textTheme.bodyMedium),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeModeSelector(Color primaryColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const modes = [
      ThemeOption(label: 'Light ☀️', mode: ThemeMode.light),
      ThemeOption(label: 'Dark 🌙', mode: ThemeMode.dark),
      ThemeOption(label: 'System 💻', mode: ThemeMode.system),
    ];

    return Row(
      children: modes.map((item) {
        final isSelected = themeController.themeMode == item.mode;
        final textColor = isSelected
            ? (isDark ? Colors.white : Colors.black)
            : (isDark ? AppColors.textSecondary : const Color(0xFF475569));

        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {});
              themeController.setThemeMode(item.mode);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? primaryColor.withOpacity(0.25) : Colors.white)
                    : (isDark ? AppColors.surface : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                border: Border.all(
                  color: isSelected ? primaryColor : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFCBD5E1)),
                  width: isSelected ? 1.5 : 1,
                ),
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
              child: Center(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorPaletteSelector() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedIdx = themeController.selectedPaletteIndex;
    final safeIndex = (selectedIdx >= 0 && selectedIdx < _accentPalettes.length)
        ? selectedIdx
        : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(_accentPalettes.length, (idx) {
        final palette = _accentPalettes[idx];
        final isSelected = safeIndex == idx;
        final labelColor = isSelected
            ? (isDark ? Colors.white : Colors.black)
            : (isDark ? AppColors.textSecondary : const Color(0xFF475569));

        return GestureDetector(
          onTap: () {
            setState(() {});
            themeController.setPalette(
              index: idx,
              primary: palette.primary,
              secondary: palette.secondary,
            );
          },
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? (isDark ? Colors.white : AppColors.primary) : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [palette.primary, palette.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(LucideIcons.check, color: Colors.white, size: 20)
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                palette.name,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _showSkillLevelDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('Default Practice Level', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: SkillLevel.values.map((level) {
              return ListTile(
                leading: Text(level.emoji, style: const TextStyle(fontSize: 16)),
                title: Text(level.displayName, style: theme.textTheme.bodyLarge),
                trailing: _defaultSkillLevel == level
                    ? Icon(LucideIcons.check, color: theme.colorScheme.primary, size: 18)
                    : null,
                onTap: () {
                  setState(() => _defaultSkillLevel = level);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showTuningDialog() {
    final theme = Theme.of(context);
    final standards = [
      'A4 = 440 Hz (Standard Concert Pitch)',
      'A4 = 432 Hz (Verdi Tuning / Scientific)',
      'A4 = 442 Hz (European Symphony Pitch)',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('Tuning Standard', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: standards.map((item) {
              final isSelected = _tuningStandard == item;
              return ListTile(
                title: Text(item, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 13)),
                trailing: isSelected
                    ? Icon(LucideIcons.check, color: theme.colorScheme.primary, size: 18)
                    : null,
                onTap: () {
                  setState(() => _tuningStandard = item);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showLatencyDialog() {
    final theme = Theme.of(context);
    final profiles = [
      'Ultra Low Latency (8ms - High CPU)',
      'Low Latency (16ms - Recommended)',
      'Balanced (32ms)',
      'Safe Buffer (64ms - Stable)',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('MIDI Buffer Latency Profile', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: profiles.map((profile) {
              final isSelected = _latencyProfile == profile;
              return ListTile(
                title: Text(profile, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 13)),
                trailing: isSelected
                    ? Icon(LucideIcons.check, color: theme.colorScheme.primary, size: 18)
                    : null,
                onTap: () {
                  setState(() => _latencyProfile = profile);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: style,
      ),
    );
  }
}
