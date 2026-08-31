import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klub_connect/routes/app_router.dart';
import 'package:klub_connect/utils/app_snackbar.dart';
import 'package:klub_connect/utils/theme.dart';

void main() {
  group('AppSnackBar Widget & Integration Tests', () {
    testWidgets('AppSnackBar.showSuccess renders success icon, message, and color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.showSuccess(context, 'Club joined successfully');
                },
                child: const Text('Show Success'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Success'));
      await tester.pumpAndSettle();

      expect(find.text('Club joined successfully'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      final iconWidget =
          tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
      expect(iconWidget.color, equals(AppTheme.successColor));
    });

    testWidgets('AppSnackBar.showError renders error icon, message, and color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.showError(
                    context,
                    'Failed to authenticate user credentials',
                  );
                },
                child: const Text('Show Error'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      expect(
        find.text('Failed to authenticate user credentials'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      final iconWidget =
          tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));
      expect(iconWidget.color, equals(AppTheme.errorColor));
    });

    testWidgets('AppSnackBar.showWarning renders warning icon, message, and color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.showWarning(
                    context,
                    'Please verify your email address',
                  );
                },
                child: const Text('Show Warning'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Warning'));
      await tester.pumpAndSettle();

      expect(find.text('Please verify your email address'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      final iconWidget =
          tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded));
      expect(iconWidget.color, equals(AppTheme.warningColor));
    });

    testWidgets('AppSnackBar.showInfo renders info icon, message, and color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.showInfo(context, 'New event details published');
                },
                child: const Text('Show Info'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Info'));
      await tester.pumpAndSettle();

      expect(find.text('New event details published'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      final iconWidget =
          tester.widget<Icon>(find.byIcon(Icons.info_outline_rounded));
      expect(iconWidget.color, equals(AppTheme.primaryColor));
    });

    testWidgets('AppSnackBar renders optional title and message hierarchy',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.showSuccess(
                    context,
                    'Your application was sent for review.',
                    title: 'Submission Received',
                  );
                },
                child: const Text('Show With Title'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show With Title'));
      await tester.pumpAndSettle();

      expect(find.text('Submission Received'), findsOneWidget);
      expect(find.text('Your application was sent for review.'), findsOneWidget);
    });

    testWidgets('AppSnackBar renders custom action button and executes callback',
        (WidgetTester tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.showInfo(
                    context,
                    'Event saved to draft',
                    action: SnackBarAction(
                      label: 'UNDO',
                      onPressed: () {
                        actionTapped = true;
                      },
                    ),
                  );
                },
                child: const Text('Show Action'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Action'));
      await tester.pumpAndSettle();

      expect(find.text('UNDO'), findsOneWidget);
      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();

      expect(actionTapped, isTrue);
    });

    testWidgets('AppSnackBar dismisses prior snackbar on new invocation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      AppSnackBar.showInfo(context, 'First Message');
                    },
                    child: const Text('Show First'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      AppSnackBar.showSuccess(context, 'Second Message');
                    },
                    child: const Text('Show Second'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show First'));
      await tester.pumpAndSettle();
      expect(find.text('First Message'), findsOneWidget);

      await tester.tap(find.text('Show Second'));
      await tester.pumpAndSettle();
      expect(find.text('Second Message'), findsOneWidget);
      expect(find.text('First Message'), findsNothing);
    });

    testWidgets('AppSnackBar uses AppRouter.currentContext when context is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AppRouter.navigatorKey,
          home: const Scaffold(
            body: Center(child: Text('Navigator Root')),
          ),
        ),
      );

      AppSnackBar.showSuccess(null, 'Global Context Message');
      await tester.pumpAndSettle();

      expect(find.text('Global Context Message'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('AppSnackBar gracefully no-ops when context and currentContext are null',
        (WidgetTester tester) async {
      expect(
        () => AppSnackBar.showSuccess(null, 'Should not throw'),
        returnsNormally,
      );
    });
  });
}
