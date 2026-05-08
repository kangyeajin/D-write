import 'package:d_write/core/services/local_data_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:d_write/core/theme/app_theme.dart';
import 'package:d_write/core/theme/theme_notifier.dart';
import 'package:d_write/core/services/notification_service.dart';
import 'package:d_write/presentation/auth/auth_gate.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  debugPrint('[LAUNCH] ① Hive.initFlutter() 완료');
  await LocalDataService().init();
  debugPrint('[LAUNCH] ② LocalDataService.init() 완료');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[LAUNCH] ③ Firebase.initializeApp() 완료');
  await NotificationService().initialize();
  debugPrint('[LAUNCH] ④ NotificationService.initialize() 완료');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, _) => MaterialApp(
          title: 'D-Write',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeNotifier.mode,
          home: const AuthGate(),
        ),
      ),
    );
  }
}
