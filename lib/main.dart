import 'package:d_write/core/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:d_write/ui/views/login_screen.dart';
import 'package:d_write/ui/views/main_screen.dart';
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
        fontFamily: 'PretendardBold', //폰트 전체 적용
        primarySwatch: Colors.blue,
      ),
      home: MainScreen(),//LoginScreen(firebaseService: FirebaseService()), // 첫 화면을 로그인 화면으로 설정
    );
  }
}