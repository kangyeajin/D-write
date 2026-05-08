import 'package:d_write/core/services/user_service.dart';
import 'package:flutter/material.dart';

enum _NicknameStatus { unchecked, checking, available, taken }

class SignupStep3Screen extends StatefulWidget {
  final IUserService userService;
  final String email;
  final String password;

  const SignupStep3Screen({
    super.key,
    required this.userService,
    required this.email,
    required this.password,
  });

  @override
  State<SignupStep3Screen> createState() => _SignupStep3ScreenState();
}

class _SignupStep3ScreenState extends State<SignupStep3Screen> {
  final _nicknameController = TextEditingController();
  _NicknameStatus _nicknameStatus = _NicknameStatus.unchecked;

  String _gender = 'private';

  bool _birthPrivate = false;
  int? _birthYear;
  int? _birthMonth;
  int? _birthDay;

  bool _locationTextViewed = false;
  bool _locationConsent = false;
  bool _privacyTextViewed = false;
  bool _privacyConsent = false;

  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _nicknameStatus == _NicknameStatus.available && _privacyConsent;

  Future<void> _checkNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('닉네임을 입력하세요.')));
      return;
    }
    if (nickname.length > 7) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('닉네임은 7글자 이하로 입력하세요.')));
      return;
    }
    setState(() => _nicknameStatus = _NicknameStatus.checking);
    final available = await widget.userService.isNicknameAvailable(nickname);
    if (!mounted) return;
    setState(() => _nicknameStatus =
        available ? _NicknameStatus.available : _NicknameStatus.taken);
  }

  Future<void> _showConsentDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    final user = await widget.userService.signUp(
      email: widget.email,
      password: widget.password,
      nickname: _nicknameController.text.trim(),
      gender: _gender,
      birthYear: _birthPrivate ? null : _birthYear,
      birthMonth: _birthPrivate ? null : _birthMonth,
      birthDay: _birthPrivate ? null : _birthDay,
      locationConsent: _locationConsent,
      privacyConsent: _privacyConsent,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user != null) {
      // AuthGate가 authStateChanges 스트림을 감지하여 MainScreen으로 전환.
      // 스택에 쌓인 Signup 화면들만 모두 pop한다.
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입에 실패했습니다. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입 (3/3)')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '프로필을 설정해주세요.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),

                // 닉네임
                _buildSectionLabel('닉네임'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nicknameController,
                        maxLength: 7,
                        decoration: const InputDecoration(
                          labelText: '닉네임 (최대 7글자)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          if (_nicknameStatus != _NicknameStatus.unchecked) {
                            setState(() => _nicknameStatus = _NicknameStatus.unchecked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _nicknameStatus == _NicknameStatus.checking
                            ? null
                            : _checkNickname,
                        child: _nicknameStatus == _NicknameStatus.checking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('중복 확인'),
                      ),
                    ),
                  ],
                ),
                _buildNicknameStatusText(),
                const SizedBox(height: 20),

                // 성별
                _buildSectionLabel('성별'),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('남자'),
                      selected: _gender == 'male',
                      onSelected: (_) => setState(() => _gender = 'male'),
                    ),
                    ChoiceChip(
                      label: const Text('여자'),
                      selected: _gender == 'female',
                      onSelected: (_) => setState(() => _gender = 'female'),
                    ),
                    ChoiceChip(
                      label: const Text('비공개'),
                      selected: _gender == 'private',
                      onSelected: (_) => setState(() => _gender = 'private'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 생년월일
                _buildSectionLabel('생년월일'),
                Row(
                  children: [
                    Expanded(child: _buildYearDropdown()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMonthDropdown()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildDayDropdown()),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: _birthPrivate,
                      onChanged: (v) => setState(() {
                        _birthPrivate = v ?? false;
                        if (_birthPrivate) {
                          _birthYear = null;
                          _birthMonth = null;
                          _birthDay = null;
                        }
                      }),
                    ),
                    const Text('비공개'),
                  ],
                ),
                const SizedBox(height: 20),

                // 위치정보 동의 (선택)
                _buildConsentRow(
                  label: '위치정보 이용약관 동의 (선택)',
                  viewed: _locationTextViewed,
                  value: _locationConsent,
                  onViewTap: () => _showConsentDialog(
                    title: '위치정보 이용약관',
                    content:
                        '위치정보 이용약관 전문입니다.\n\n[전문 내용은 추후 입력]\n\n본 약관에 동의하시면 위치 기반 서비스를 이용하실 수 있습니다.',
                    onConfirm: () => setState(() => _locationTextViewed = true),
                  ),
                  onChanged: _locationTextViewed
                      ? (v) => setState(() => _locationConsent = v ?? false)
                      : null,
                ),

                // 개인정보 동의 (필수)
                _buildConsentRow(
                  label: '개인정보 처리방침 동의 (필수)',
                  viewed: _privacyTextViewed,
                  value: _privacyConsent,
                  onViewTap: () => _showConsentDialog(
                    title: '개인정보 처리방침',
                    content:
                        '개인정보 처리방침 전문입니다.\n\n[전문 내용은 추후 입력]\n\n본 방침에 동의하시면 서비스 이용이 가능합니다.',
                    onConfirm: () => setState(() => _privacyTextViewed = true),
                  ),
                  onChanged: _privacyTextViewed
                      ? (v) => setState(() => _privacyConsent = v ?? false)
                      : null,
                ),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: const Text('가입 완료'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
    );
  }

  Widget _buildNicknameStatusText() {
    switch (_nicknameStatus) {
      case _NicknameStatus.available:
        return const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('사용 가능한 닉네임입니다.', style: TextStyle(color: Colors.green)),
        );
      case _NicknameStatus.taken:
        return const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('이미 사용 중인 닉네임입니다.', style: TextStyle(color: Colors.red)),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildYearDropdown() {
    final years = List.generate(100, (i) => DateTime.now().year - i);
    return DropdownButtonFormField<int>(
      initialValue: _birthYear,
      hint: const Text('연도'),
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: _birthPrivate
          ? []
          : years
              .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
              .toList(),
      onChanged: _birthPrivate ? null : (v) => setState(() => _birthYear = v),
    );
  }

  Widget _buildMonthDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _birthMonth,
      hint: const Text('월'),
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: _birthPrivate
          ? []
          : List.generate(
              12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}월')),
            ),
      onChanged: _birthPrivate ? null : (v) => setState(() => _birthMonth = v),
    );
  }

  Widget _buildDayDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _birthDay,
      hint: const Text('일'),
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: _birthPrivate
          ? []
          : List.generate(
              31, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}일')),
            ),
      onChanged: _birthPrivate ? null : (v) => setState(() => _birthDay = v),
    );
  }

  Widget _buildConsentRow({
    required String label,
    required bool viewed,
    required bool value,
    required VoidCallback onViewTap,
    required ValueChanged<bool?>? onChanged,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
        ),
        Expanded(child: Text(label)),
        TextButton(
          onPressed: onViewTap,
          child: Text(
            '전문보기',
            style: TextStyle(color: viewed ? Colors.grey : null),
          ),
        ),
      ],
    );
  }
}
