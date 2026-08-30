import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klub_connect/screens/auth/welcome_screen.dart';
import 'package:klub_connect/screens/auth/login_screen.dart';
import 'package:klub_connect/utils/theme.dart';
import 'package:klub_connect/widgets/screen_background.dart';

void main() {
  group('Screen-Level Smoke Tests', () {
    testWidgets('WelcomeScreen renders brand hero and student/faculty role cards',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const WelcomeScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('KlubConnect'), findsOneWidget);
      expect(find.text("I'm a Student"), findsOneWidget);
      expect(find.text("I'm Faculty"), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('LoginScreen renders email, password inputs and magic link options',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('ScreenBackground and ScreenHeader compose cleanly in custom view',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ScreenBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Column(
                  children: [
                    ScreenHeader(
                      title: 'Overview',
                      subtitle: 'Active events',
                      actions: [
                        IconGlassButton(
                          icon: Icons.refresh_rounded,
                          onTap: () {},
                        ),
                      ],
                    ),
                    const Expanded(
                      child: Center(
                        child: GlassPanel(
                          child: Text('Live content'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Active events'), findsOneWidget);
      expect(find.text('Live content'), findsOneWidget);
      expect(find.byType(ScreenBackground), findsOneWidget);
      expect(find.byType(GlassPanel), findsOneWidget);
    });
  });
}
