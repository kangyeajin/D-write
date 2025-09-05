import 'package:d_write/core/services/firebase_service.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart'; // 로그인 화면 import 추가

class FirebaseTestScreen extends StatefulWidget {
  // 생성자를 통해 외부에서 FirebaseService를 주입받습니다.
  final IFirebaseService firebaseService;

  const FirebaseTestScreen({super.key, required this.firebaseService});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _infoController = TextEditingController();

  void _handleSignUp() async {
    final user = await widget.firebaseService.signUp(
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
              // 주입받은 firebaseService를 LoginScreen에 다시 전달합니다.
              builder: (context) =>
                  LoginScreen(firebaseService: widget.firebaseService),
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

  void _handleSignIn() async {
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              LoginScreen(firebaseService: widget.firebaseService),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase 연동 테스트')),
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
              onPressed: _handleSignUp,
              child: const Text('회원가입'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _handleSignIn,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}
