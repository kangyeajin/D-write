import 'package:d_write/core/services/user_service.dart';
import 'package:d_write/core/utils/snack_bar_utils.dart';
import 'package:d_write/presentation/auth/google_signup_profile_screen.dart';
import 'package:d_write/presentation/auth/signup_step1_screen.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final IUserService userService;

  const LoginScreen({super.key, required this.userService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  Future<void> _login() async {
    setState(() => _isLoading = true);

    final user = await widget.userService.signIn(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user == null) {
      showAppSnackBar(context, '로그인에 실패했습니다.');
    }
    // 로그인 성공 시 AuthGate가 authStateChanges 스트림을 감지하여 MainScreen으로 전환
  }

  void _regist() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            SignupStep1Screen(userService: widget.userService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  key: const Key('email_field'),
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: '이메일'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  key: const Key('password_field'),
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  key: const Key('login_button'),
                  onPressed: _isLoading ? null : _login,
                  child: const Text('로그인'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _regist,
                  child: const Text('회원가입'),
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
              ],
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
