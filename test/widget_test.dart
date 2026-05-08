// Basic widget smoke test — does not import main.dart to avoid firebase_options dependency.
import 'package:d_write/presentation/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'login_screen_test.mocks.dart';

void main() {
  testWidgets('LoginScreen renders correctly', (WidgetTester tester) async {
    final mockService = MockIFirebaseService();

    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(userService: mockService),
    ));

    expect(find.byKey(const Key('email_field')), findsOneWidget);
    expect(find.byKey(const Key('password_field')), findsOneWidget);
    expect(find.byKey(const Key('login_button')), findsOneWidget);
  });
}
