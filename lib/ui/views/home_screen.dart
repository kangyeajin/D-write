import 'package:d_write/core/services/user_service.dart';
import 'package:d_write/ui/views/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final User user;
  final IUserService userService;

  const HomeScreen({super.key, required this.user, required this.userService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('로그인 성공!'),
            const SizedBox(height: 20),
            Text('UID: ${user.uid}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await userService.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(userService: userService),
                  ),
                );
              },
              child: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }
}
