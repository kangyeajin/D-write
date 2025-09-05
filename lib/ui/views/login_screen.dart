import 'package:d_write/core/services/firebase_service.dart';
import 'package:d_write/ui/views/home_screen.dart';
import 'package:d_write/ui/views/register_screen.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final IFirebaseService firebaseService;

  const LoginScreen({super.key, required this.firebaseService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    setState(() {
      _isLoading = true;
    });

    final user = await widget.firebaseService.signIn(
      _emailController.text,
      _passwordController.text,
    );

    if (mounted) {
      if (user != null) {
        // 로그인 성공 시 HomeScreen으로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              user: user,
              firebaseService: widget.firebaseService,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인에 실패했습니다.')),
        );
      }
    }

    // 위에서 화면 전환이 일어나면 아래 코드는 실행되지 않을 수 있으므로, 실패 시에만 로딩 상태를 해제합니다.
    if (mounted && _isLoading) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _regist() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FirebaseTestScreen(firebaseService: widget.firebaseService),
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
              ],
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
