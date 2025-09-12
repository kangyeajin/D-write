import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:d_write/ui/views/main_screen.dart';
import 'firebase_options.dart'; // flutterfire configure를 통해 생성됨

void main() async { 
  // 앱 실행 전 Firebase 초기화 
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // super.key : 위젯 식별용, 동일한 위젯명 없으면 삭제해도 오류 X

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple App',
      theme: ThemeData(
        fontFamily: 'PretendardBold', //폰트 전체 적용
        primarySwatch: Colors.blue,
      ),
      home: const MainScreen(),
    );
  }
}