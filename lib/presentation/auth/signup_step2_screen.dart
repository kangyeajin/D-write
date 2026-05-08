import 'package:d_write/core/services/user_service.dart';
import 'package:d_write/presentation/auth/signup_step3_screen.dart';
import 'package:flutter/material.dart';

class SignupStep2Screen extends StatefulWidget {
  final IUserService userService;
  final String email;

  const SignupStep2Screen({
    super.key,
    required this.userService,
    required this.email,
  });

  @override
  State<SignupStep2Screen> createState() => _SignupStep2ScreenState();
}

class _SignupStep2ScreenState extends State<SignupStep2Screen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isLongEnough => _passwordController.text.length >= 6;
  bool get _matches =>
      _confirmController.text.isNotEmpty &&
      _passwordController.text == _confirmController.text;
  bool get _canProceed => _isLongEnough && _matches;

  void _next() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SignupStep3Screen(
          userService: widget.userService,
          email: widget.email,
          password: _passwordController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confirmMismatch =
        _confirmController.text.isNotEmpty && !_matches;

    return Scaffold(
      appBar: AppBar(title: const Text('회원가입 (2/3)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '비밀번호를 설정해주세요.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: !_showPassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '비밀번호 (6자 이상)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              obscureText: !_showConfirm,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                color: confirmMismatch ? Colors.red : null,
              ),
              decoration: InputDecoration(
                labelText: '비밀번호 확인',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_confirmController.text.isNotEmpty)
                      Icon(
                        _matches ? Icons.check_circle : Icons.cancel,
                        color: _matches ? Colors.green : Colors.red,
                      ),
                    IconButton(
                      icon: Icon(
                        _showConfirm ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _showConfirm = !_showConfirm),
                    ),
                  ],
                ),
                errorText: confirmMismatch ? '비밀번호가 일치하지 않습니다.' : null,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _canProceed ? _next : null,
              child: const Text('다음'),
            ),
          ],
        ),
      ),
    );
  }
}
