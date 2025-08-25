import 'package:flutter/material.dart';
import '../../core/services/firebase_service.dart'; // 방금 만든 서비스 파일 import
import './login_screen.dart'; // 로그인 화면 import 추가

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _infoController = TextEditingController();

  // 회원가입 버튼을 눌렀을 때 실행될 함수
  // 회원가입 성공 -> 로그인 화면으로 이동
  // MaterialPageRoute(builder: (context) => const LoginScreen()) 사용
  void _handleSignUp() async {
    final user = await _firebaseService.signUp(
      _emailController.text,
      _passwordController.text,
      _nameController.text,
      _infoController.text,
    );

    if (mounted) { // 위젯이 여전히 화면에 있는지 확인
      if (user != null) {
        // 회원가입 성공 시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 성공! 로그인 페이지로 이동합니다.')),
        );

        // 1초 후 로그인 화면으로 이동
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()), // LoginScreen()으로 이동
          );
        });

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입에 실패했습니다.')),
        );
      }
    }
  }

  // 로그인 버튼을 눌렀을 때 실행될 함수
  void _handleSignIn() async {
    // 1초 후 로그인 화면으로 이동
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });

    // final user = await _firebaseService.signIn(
    //   _emailController.text,
    //   _passwordController.text,
    // );

    // if (mounted) {
    //   if (user != null) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(content: Text('로그인 성공! 환영합니다, ${user.email}')),
    //     );
    //   } else {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(content: Text('로그인에 실패했습니다.')),
    //     );
    //   }
    // }
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