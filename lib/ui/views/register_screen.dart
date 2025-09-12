import 'package:d_write/core/services/user_service.dart';
import 'package:d_write/ui/views/login_screen.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  final IUserService userService;

  const RegisterScreen({super.key, required this.userService});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _infoController = TextEditingController();

  void _signUp() async {
    // 회원가입 로직
    final user = await widget.userService.signUp(
      _emailController.text,
      _passwordController.text,
      _nameController.text,
      _infoController.text,
    );

    if (mounted) {
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 성공! 로그인 페이지로 이동합니다.')),
        );

        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              // 주입받은 userService를 LoginScreen에 다시 전달합니다.
              builder: (context) =>
                  LoginScreen(userService: widget.userService),
            ),
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입에 실패했습니다.')),
        );
      }
    }
  }

  void _goToLoginScreen() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LoginScreen(userService: widget.userService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: '이메일'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: '비밀번호'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _infoController,
              decoration: const InputDecoration(labelText: '정보'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _signUp,
              child: const Text('회원가입'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _goToLoginScreen,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('로그인 화면으로'),
            ),
          ],
        ),
      ),
    );
  }
}
