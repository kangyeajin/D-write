import 'package:d_write/core/services/notification_service.dart';
import 'package:d_write/core/services/user_service.dart';
import 'package:d_write/core/theme/app_palette.dart';
import 'package:d_write/core/theme/app_text_styles.dart';
import 'package:d_write/core/theme/theme_notifier.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AppOptionsScreen extends StatefulWidget {
  const AppOptionsScreen({super.key});

  @override
  State<AppOptionsScreen> createState() => _AppOptionsScreenState();
}

class _AppOptionsScreenState extends State<AppOptionsScreen> {
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();

  bool _notifPopup = false;
  bool _notifSound = false;
  bool _notifVibration = false;
  String _theme = 'light';
  String _palette = 'fog';
  TimeOfDay? _notifTime;
  bool _isLoading = true;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static const String _contactEmail = 'bosko413@naver.com';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = _uid;
    if (uid == null) return;
    final profile = await _userService.getUserProfile(uid);
    if (!mounted || profile == null) return;
    setState(() {
      _notifPopup = profile.notifPopup;
      _notifSound = profile.notifSound;
      _notifVibration = profile.notifVibration;
      _theme = profile.theme;
      _palette = profile.palette;
      _notifTime = _parseTime(profile.notifTime);
      _isLoading = false;
    });
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatTimeValue(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _updateField(String field, dynamic value) async {
    final uid = _uid;
    if (uid == null) return;
    await _userService.updateSettings(uid, {field: value});
  }

  Future<void> _syncNotification() async {
    if (!_notifPopup) {
      await _notificationService.cancelDailyNotification();
      return;
    }
    final time = _notifTime;
    if (time == null) return;
    await _notificationService.scheduleDailyNotification(
      time: time,
      withSound: _notifSound,
      withVibration: _notifVibration,
    );
  }

  void _togglePopup() async {
    final next = !_notifPopup;
    if (next) {
      final granted = await _notificationService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '알림 권한이 거부되었습니다. 시스템 설정에서 알림을 허용한 후 다시 시도해 주세요.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }
    setState(() => _notifPopup = next);
    await _updateField('notifPopup', next);
    await _syncNotification();
  }

  void _toggleSound() async {
    final next = !_notifSound;
    setState(() => _notifSound = next);
    await _updateField('notifSound', next);
    await _syncNotification();
  }

  void _toggleVibration() async {
    final next = !_notifVibration;
    setState(() => _notifVibration = next);
    await _updateField('notifVibration', next);
    await _syncNotification();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notifTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() => _notifTime = picked);
    await _updateField('notifTime', _formatTimeValue(picked));
    await _syncNotification();
  }

  void _setTheme(String theme) {
    if (_theme == theme) return;
    setState(() => _theme = theme);
    _updateField('theme', theme);
    context.read<ThemeNotifier>().setTheme(theme);
  }

  void _setPalette(String paletteId) {
    if (_palette == paletteId) return;
    setState(() => _palette = paletteId);
    _updateField('palette', paletteId);
    context.read<ThemeNotifier>().setPaletteById(paletteId);
  }

  Future<void> _launchEmail() async {
    final uri = Uri(scheme: 'mailto', path: _contactEmail);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text(
          '앱 설정',
          style: AppTextStyles.sectionTitle
              .copyWith(color: colors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('알림 설정', style: AppTextStyles.sectionTitle.copyWith(color: colors.textPrimary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SelectChip(
                    label: '팝업',
                    isSelected: _notifPopup,
                    onTap: _togglePopup,
                  ),
                  const SizedBox(width: 8),
                  _SelectChip(
                    label: '소리',
                    isSelected: _notifSound,
                    onTap: _toggleSound,
                  ),
                  const SizedBox(width: 8),
                  _SelectChip(
                    label: '진동',
                    isSelected: _notifVibration,
                    onTap: _toggleVibration,
                  ),
                ],
              ),
              if (_notifPopup) ...[
                const SizedBox(height: 20),
                Text('알림 시간', style: AppTextStyles.sectionTitle.copyWith(color: colors.textPrimary)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickTime,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: _notifTime != null
                          ? colors.surface
                          : colors.background,
                      border: Border.all(color: colors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _notifTime != null
                              ? _notifTime!.format(context)
                              : '시간 선택',
                          style: AppTextStyles.button.copyWith(color: colors.textPrimary),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, size: 16, color: colors.textPrimary),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              Text('앱 테마', style: AppTextStyles.sectionTitle.copyWith(color: colors.textPrimary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SelectChip(
                    label: '라이트 모드',
                    isSelected: _theme == 'light',
                    onTap: () => _setTheme('light'),
                  ),
                  const SizedBox(width: 8),
                  _SelectChip(
                    label: '다크모드',
                    isSelected: _theme == 'dark',
                    onTap: () => _setTheme('dark'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text('컬러 테마', style: AppTextStyles.sectionTitle.copyWith(color: colors.textPrimary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: AppPalette.values.map((p) {
                  final isSelected = _palette == p.id;
                  return _PaletteChip(
                    palette: p,
                    isSelected: isSelected,
                    onTap: () => _setPalette(p.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
              Text('도움말 및 문의사항', style: AppTextStyles.sectionTitle.copyWith(color: colors.textPrimary)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _launchEmail,
                child: Text(_contactEmail, style: AppTextStyles.body.copyWith(color: colors.textPrimary)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? colors.surface : colors.background,
          border: Border.all(
            color: isSelected ? colors.accent : colors.divider,
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.button.copyWith(color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// 팔레트 선택 칩 — accent 색상 점으로 팔레트 미리보기
class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  final AppPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  // 팔레트별 accent 색상 (라이트 기준)
  static const _accentColors = {
    AppPalette.fog:  Color(0xFF7B8FA1),
    AppPalette.sand: Color(0xFFB5714E),
    AppPalette.moss: Color(0xFF697A5E),
    AppPalette.dawn: Color(0xFFC4826A),
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    final accent = _accentColors[palette]!;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? colors.surface : colors.background,
          border: Border.all(
            color: isSelected ? accent : colors.divider,
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              palette.label,
              style: AppTextStyles.button.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
