import 'package:flutter/material.dart';
import 'package:d_write/core/services/firebase_service.dart';
import './register_screen.dart'; // 로그인 화면 import 추가

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _login() async {
    final user = await _firebaseService.signIn(
      _emailController.text,
      _passwordController.text,
    );

    if (mounted) {
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 성공! 환영합니다, ${user.email}')),
        );
        // 메인화면 이동
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인에 실패했습니다.')),
        );
      }
    }

    // final userCredential = await _firebaseService.signInWithEmail(
    //   _emailController.text,
    //   _passwordController.text,
    // );
    // if (userCredential != null) {
    //   Navigator.pushReplacement(
    //     context,
    //     MaterialPageRoute(builder: (context) => HomeScreen(user: userCredential.user!)),
    //   );
    // } else {
    //   // 로그인 실패 시 간단한 스낵바 표시
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('로그인에 실패했습니다.')),
    //   );
    // }
  }

  void _regist() {
    // 1초 후 회원가입 화면으로 이동
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const FirebaseTestScreen()), // 회원가입 페이지 이동
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('로그인')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: '이메일'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: '비밀번호'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text('로그인'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _regist,
              child: Text('회원가입'),
            ),
          ],
        ),
      ),
    );
  }
}