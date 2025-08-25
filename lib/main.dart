import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:d_write/ui/views/login_screen.dart';
import 'firebase_options.dart'; // flutterfire configure를 통해 생성됨

void main() async {
  // Flutter 앱이 실행되기 전에 Firebase를 초기화합니다.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginScreen(), // 첫 화면을 로그인 화면으로 설정
    );
  }
}