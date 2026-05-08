import 'package:d_write/core/models/user_model.dart';
import 'package:d_write/core/services/like_service.dart';
import 'package:d_write/core/services/memo_service.dart';
import 'package:d_write/core/theme/app_colors.dart';
import 'package:d_write/core/theme/app_text_styles.dart';
import 'package:d_write/repositories/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  final _userRepo = UserRepository();
  final _likeService = LikeService();
  final _memoService = MemoService();

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  UserProfile? _profile;
  int _likeCount = 0;
  int _memoCount = 0;

  // 수정 상태
  late TextEditingController _nicknameCtrl;
  String _editGender = 'private';
  int? _editBirthYear;
  int? _editBirthMonth;
  int? _editBirthDay;

  @override
  void initState() {
    super.initState();
    _nicknameCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    final results = await Future.wait([
      _userRepo.getUser(uid),
      _likeService.getLikesForUser(uid),
      _memoService.getMemosForUser(uid),
    ]);
    if (!mounted) return;
    setState(() {
      _profile = results[0] as UserProfile?;
      _likeCount = (results[1] as List).length;
      _memoCount = (results[2] as List).length;
      _isLoading = false;
    });
  }

  // ── 수정 ──────────────────────────────────────────────────────────────
  void _startEdit() {
    final p = _profile;
    if (p == null) return;
    _nicknameCtrl.text = p.nickname;
    _editGender = p.gender;
    _editBirthYear = p.birthYear;
    _editBirthMonth = p.birthMonth;
    _editBirthDay = p.birthDay;
    setState(() => _isEditing = true);
  }

  void _cancelEdit() => setState(() => _isEditing = false);

  Future<void> _saveEdit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final profile = _profile;
    if (uid == null || profile == null) return;

    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final fields = <String, dynamic>{
        'nickname': nickname,
        'gender': _editGender,
        if (_editBirthYear != null) 'birthYear': _editBirthYear,
        if (_editBirthMonth != null) 'birthMonth': _editBirthMonth,
        if (_editBirthDay != null) 'birthDay': _editBirthDay,
      };
      await _userRepo.updateProfileFields(uid, fields);
      setState(() {
        _profile = profile.copyWith(
          nickname: nickname,
          gender: _editGender,
          birthYear: _editBirthYear,
          birthMonth: _editBirthMonth,
          birthDay: _editBirthDay,
        );
        _isEditing = false;
        _isSaving = false;
      });
    } catch (_) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했습니다.')),
        );
      }
    }
  }

  Future<void> _pickBirthDate() async {
    final initial = (_editBirthYear != null)
        ? DateTime(_editBirthYear!, _editBirthMonth ?? 1, _editBirthDay ?? 1)
        : DateTime(2000);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _editBirthYear = picked.year;
        _editBirthMonth = picked.month;
        _editBirthDay = picked.day;
      });
    }
  }

  // ── 비밀번호 변경 다이얼로그 ───────────────────────────────────────────
  void _showPasswordDialog() {
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('비밀번호 변경'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: newPwCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '새 비밀번호',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPwCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '새 비밀번호 확인',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: AppTextStyles.errorText),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final pw = newPwCtrl.text;
                  final confirm = confirmPwCtrl.text;
                  if (pw.length < 8) {
                    setDialogState(
                        () => errorText = '비밀번호는 8자 이상이어야 합니다.');
                    return;
                  }
                  if (pw != confirm) {
                    setDialogState(
                        () => errorText = '비밀번호가 일치하지 않습니다.');
                    return;
                  }
                  try {
                    await FirebaseAuth.instance.currentUser
                        ?.updatePassword(pw);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('비밀번호가 변경되었습니다.')),
                      );
                    }
                  } on FirebaseAuthException catch (e) {
                    setDialogState(() => errorText = _pwError(e.code));
                  }
                },
                child: const Text('변경'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _pwError(String code) {
    switch (code) {
      case 'requires-recent-login':
        return '보안을 위해 재로그인 후 변경해주세요.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다.';
      default:
        return '오류가 발생했습니다. 다시 시도해주세요.';
    }
  }

  // ── 헬퍼 ──────────────────────────────────────────────────────────────
  String _genderLabel(String g) {
    switch (g) {
      case 'male':
        return '남성';
      case 'female':
        return '여성';
      default:
        return '비공개';
    }
  }

  String get _birthdayLabel {
    final p = _profile;
    if (p == null || p.birthYear == null) return '미설정';
    return '${p.birthYear}.'
        '${p.birthMonth?.toString().padLeft(2, '0')}.'
        '${p.birthDay?.toString().padLeft(2, '0')}';
  }

  String get _editBirthdayLabel {
    if (_editBirthYear == null) return '미설정';
    return '$_editBirthYear.'
        '${_editBirthMonth?.toString().padLeft(2, '0')}.'
        '${_editBirthDay?.toString().padLeft(2, '0')}';
  }

  String get _providerLabel {
    final providers =
        FirebaseAuth.instance.currentUser?.providerData ?? [];
    if (providers.isEmpty) return '없음';
    switch (providers.first.providerId) {
      case 'password':
        return '이메일';
      case 'google.com':
        return '구글';
      case 'apple.com':
        return '애플';
      default:
        return providers.first.providerId;
    }
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        title: const Text('내 정보'),
        foregroundColor: AppColors.onBackgroundLight,
        actions: [
          if (!_isLoading && _profile != null)
            _isEditing
                ? Row(
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : _cancelEdit,
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: _isSaving ? null : _saveEdit,
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text(
                                '완료',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ],
                  )
                : TextButton(
                    onPressed: _startEdit,
                    child: const Text('수정'),
                  ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(),
                  _buildStatRow(),
                  const Divider(height: 1, color: AppColors.dividerLight),
                  const SizedBox(height: 8),
                  _buildInfoSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final nickname = _profile?.nickname ?? '사용자';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.surfaceLight,
            child: Text(
              nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.onBackgroundLight,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nickname,
                style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700, fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(_profile?.email ?? '', style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
                icon: Icons.thumb_up_alt_outlined,
                value: '$_likeCount',
                label: '좋아요'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _StatCard(
                icon: Icons.note_alt_outlined,
                value: '$_memoCount',
                label: '메모'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    final p = _profile!;
    return Column(
      children: [
        // 닉네임
        _InfoRow(
          label: '닉네임',
          child: _isEditing
              ? SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _nicknameCtrl,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: UnderlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                )
              : Text(p.nickname, style: AppTextStyles.body),
        ),
        _Divider(),
        // 아이디
        _InfoRow(
          label: '아이디',
          child: Text(p.email, style: AppTextStyles.bodySmall),
        ),
        _Divider(),
        // 성별
        _InfoRow(
          label: '성별',
          child: _isEditing
              ? _GenderSelector(
                  value: _editGender,
                  onChanged: (v) => setState(() => _editGender = v),
                )
              : Text(_genderLabel(p.gender), style: AppTextStyles.body),
        ),
        _Divider(),
        // 생일
        _InfoRow(
          label: '생일',
          child: _isEditing
              ? GestureDetector(
                  onTap: _pickBirthDate,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_editBirthdayLabel, style: AppTextStyles.body),
                      const SizedBox(width: 6),
                      const Icon(Icons.calendar_today_outlined,
                          size: 15, color: AppColors.subtitleLight),
                    ],
                  ),
                )
              : Text(_birthdayLabel, style: AppTextStyles.body),
        ),
        _Divider(),
        // 비밀번호 변경
        InkWell(
          onTap: _showPasswordDialog,
          child: const _InfoRow(
            label: '비밀번호 변경',
            child: Icon(Icons.chevron_right,
                size: 20, color: AppColors.subtitleLight),
          ),
        ),
        _Divider(),
        // 연동된 계정
        _InfoRow(
          label: '연동된 계정',
          child: Text(_providerLabel, style: AppTextStyles.body),
        ),
        const SizedBox(height: 40),
        Center(
          child: TextButton(
            onPressed: _logout,
            child: const Text(
              '로그아웃',
              style: TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

// ── 재사용 위젯 ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.onSurfaceLight),
          const SizedBox(height: 6),
          Text(value,
              style: AppTextStyles.body
                  .copyWith(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _InfoRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: child),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, indent: 24, endIndent: 24, color: AppColors.dividerLight);
  }
}

class _GenderSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _GenderSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip('남성', 'male'),
        const SizedBox(width: 8),
        _chip('여성', 'female'),
        const SizedBox(width: 8),
        _chip('비공개', 'private'),
      ],
    );
  }

  Widget _chip(String label, String val) {
    final selected = value == val;
    return GestureDetector(
      onTap: () => onChanged(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.dividerLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : AppColors.onSurfaceLight,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
