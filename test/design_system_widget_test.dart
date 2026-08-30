import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klub_connect/widgets/screen_background.dart';
import 'package:klub_connect/widgets/glass_card.dart';

void main() {
  group('Design System & Glassmorphic Widget Tests', () {
    testWidgets('ScreenBackground renders ambient gradient mesh and child',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScreenBackground(
              child: Center(
                child: Text('Ambient Canvas Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Ambient Canvas Content'), findsOneWidget);
      expect(find.byType(ScreenBackground), findsOneWidget);
      expect(find.byType(Stack), findsWidgets);
    });

    testWidgets('GlassPanel renders with custom border, padding, and handles tap',
        (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassPanel(
              onTap: () => tapped = true,
              borderRadius: 24,
              child: const Text('Frosted Panel'),
            ),
          ),
        ),
      );

      expect(find.text('Frosted Panel'), findsOneWidget);
      await tester.tap(find.text('Frosted Panel'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('IconGlassButton renders icon and triggers onTap callback',
        (WidgetTester tester) async {
      bool buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconGlassButton(
              icon: Icons.notifications_rounded,
              onTap: () => buttonPressed = true,
              size: 48,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.notifications_rounded));
      await tester.pumpAndSettle();

      expect(buttonPressed, isTrue);
    });

    testWidgets('ScreenHeader renders title, subtitle, back button and action',
        (WidgetTester tester) async {
      bool backTapped = false;
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenHeader(
              title: 'Event Hub',
              subtitle: 'Campus Activities',
              onBack: () => backTapped = true,
              actions: [
                IconGlassButton(
                  icon: Icons.search_rounded,
                  onTap: () => actionTapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Event Hub'), findsOneWidget);
      expect(find.text('Campus Activities'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(backTapped, isTrue);

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      expect(actionTapped, isTrue);
    });

    testWidgets('GlassCard backward compatibility wrapper renders child',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassCard(
              borderRadius: 16,
              child: Text('Legacy Glass Card Child'),
            ),
          ),
        ),
      );

      expect(find.text('Legacy Glass Card Child'), findsOneWidget);
    });
  });
}
