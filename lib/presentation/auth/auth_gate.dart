import 'package:d_write/core/services/user_service.dart';
import 'package:d_write/presentation/auth/login_screen.dart';
import 'package:d_write/presentation/main/main_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// 앱 진입점에서 인증 상태를 감지하여 화면을 분기하는 게이트.
/// - 로그인 상태  → MainScreen
/// - 미로그인 상태 → LoginScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const MainScreen();
        }
        return LoginScreen(userService: UserService());
      },
    );
  }
}
