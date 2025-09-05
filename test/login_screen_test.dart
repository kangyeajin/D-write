
import 'package:d_write/core/services/firebase_service.dart';
import 'package:d_write/ui/views/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'login_screen_test.mocks.dart';

// MockFirebaseService 클래스를 생성하도록 build_runner에게 지시합니다.
@GenerateMocks([IFirebaseService, auth.User])
void main() {
  // 테스트에 사용할 가짜(Mock) 객체들을 선언합니다.
  late MockIFirebaseService mockFirebaseService;
  late MockUser mockUser;

  // 각 테스트가 실행되기 전에 호출됩니다.
  setUp(() {
    // 새 Mock 객체를 생성하여 각 테스트가 격리된 환경에서 실행되도록 합니다.
    mockFirebaseService = MockIFirebaseService();
    mockUser = MockUser();
  });

  testWidgets('LoginScreen success flow', (WidgetTester tester) async {
    // --- ARRANGE (준비) ---
    // 1. mockFirebaseService.signIn 메소드가 호출될 때의 동작을 정의합니다.
    //    어떤 이메일/비밀번호가 들어오든, 1초 후에 mockUser를 반환하도록 설정합니다.
    when(mockFirebaseService.signIn(any, any)).thenAnswer((_) async {
      await Future.delayed(const Duration(seconds: 1));
      return mockUser;
    });
    // 2. mockUser.email이 호출될 때 'test@example.com'을 반환하도록 설정합니다.
    when(mockUser.email).thenReturn('test@example.com');

    // --- ACT (실행) ---
    // 3. LoginScreen 위젯을 빌드하고, mockFirebaseService를 주입합니다.
    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(firebaseService: mockFirebaseService),
    ));

    // 4. 초기 UI 상태를 검증합니다.
    expect(find.byKey(const Key('email_field')), findsOneWidget);
    expect(find.byKey(const Key('password_field')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // 5. 이메일과 비밀번호를 입력합니다.
    await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com');
    await tester.enterText(find.byKey(const Key('password_field')), 'password');

    // 6. 로그인 버튼을 탭합니다.
    await tester.tap(find.byKey(const Key('login_button')));

    // --- ASSERT (검증) ---
    // 7. 로딩 인디케이터가 나타날 때까지 프레임을 진행시킵니다.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 8. 모든 비동기 작업(Future.delayed 포함)이 끝날 때까지 기다립니다.
    await tester.pumpAndSettle();

    // 9. 로딩 인디케이터가 사라졌는지 확인합니다.
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // 10. 로그인 성공 스낵바가 나타났는지 확인합니다.
    expect(find.text('로그인 성공! 환영합니다, test@example.com'), findsOneWidget);
  });

  testWidgets('LoginScreen failure flow', (WidgetTester tester) async {
    // --- ARRANGE (준비) ---
    // 1. signIn 메소드가 호출될 때 null을 반환하여 로그인 실패를 시뮬레이션합니다.
    when(mockFirebaseService.signIn(any, any)).thenAnswer((_) async {
      await Future.delayed(const Duration(seconds: 1));
      return null;
    });

    // --- ACT (실행) ---
    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(firebaseService: mockFirebaseService),
    ));
    await tester.enterText(find.byKey(const Key('email_field')), 'wrong@example.com');
    await tester.enterText(find.byKey(const Key('password_field')), 'wrong');
    await tester.tap(find.byKey(const Key('login_button')));

    // --- ASSERT (검증) ---
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // 로그인 실패 스낵바가 나타났는지 확인합니다.
    expect(find.text('로그인에 실패했습니다.'), findsOneWidget);
  });
}
