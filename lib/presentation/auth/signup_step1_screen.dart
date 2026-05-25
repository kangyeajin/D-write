import 'package:d_write/core/services/user_service.dart';
import 'package:d_write/core/utils/snack_bar_utils.dart';
import 'package:d_write/presentation/auth/google_signup_profile_screen.dart';
import 'package:d_write/presentation/auth/signup_step2_screen.dart';
import 'package:flutter/material.dart';

enum _EmailStatus { unchecked, checking, available, taken }

class SignupStep1Screen extends StatefulWidget {
  final IUserService userService;

  const SignupStep1Screen({super.key, required this.userService});

  @override
  State<SignupStep1Screen> createState() => _SignupStep1ScreenState();
}

class _SignupStep1ScreenState extends State<SignupStep1Screen> {
  final _emailController = TextEditingController();
  _EmailStatus _status = _EmailStatus.unchecked;
  bool _googleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _canProceed => _status == _EmailStatus.available;

  Future<void> _checkEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showAppSnackBar(context, '올바른 이메일 형식을 입력하세요.');
      return;
    }
    setState(() => _status = _EmailStatus.checking);
    final available = await widget.userService.isEmailAvailable(email);
    if (!mounted) return;
    setState(() => _status = available ? _EmailStatus.available : _EmailStatus.taken);
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    final result = await widget.userService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);

    if (result.user == null) return;

    if (result.isNewUser) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GoogleSignupProfileScreen(
            userService: widget.userService,
            user: result.user!,
          ),
        ),
      );
    }
    // 기존 회원: AuthGate가 authStateChanges 스트림을 감지하여 자동 전환
  }

  void _next() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SignupStep2Screen(
          userService: widget.userService,
          email: _emailController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입 (1/3)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '이메일을 입력해주세요.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) {
                      if (_status != _EmailStatus.unchecked) {
                        setState(() => _status = _EmailStatus.unchecked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _status == _EmailStatus.checking ? null : _checkEmail,
                    child: _status == _EmailStatus.checking
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
            const SizedBox(height: 8),
            _buildStatusText(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _canProceed ? _next : null,
              child: const Text('다음'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: _googleLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.g_mobiledata),
              label: const Text('구글로 이용하기'),
              onPressed: _googleLoading ? null : _signInWithGoogle,
            ),
            const SizedBox(height: 8),
            const OutlinedButton(
              onPressed: null, // Phase 11
              child: Text('카카오로 이용하기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    switch (_status) {
      case _EmailStatus.available:
        return const Text('사용 가능한 이메일입니다.', style: TextStyle(color: Colors.green));
      case _EmailStatus.taken:
        return const Text('이미 사용 중인 이메일입니다.', style: TextStyle(color: Colors.red));
      default:
        return const SizedBox.shrink();
    }
  }
}
