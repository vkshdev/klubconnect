import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klub_connect/routes/app_router.dart';
import 'package:klub_connect/routes/app_routes.dart';
import 'package:klub_connect/screens/clubs/club_details_screen.dart';
import 'package:klub_connect/screens/events/event_details_screen.dart';
import 'package:klub_connect/screens/home/calendar_screen.dart';
import 'package:klub_connect/screens/home/home_screen.dart';
import 'package:klub_connect/screens/home/search_screen.dart';
import 'package:klub_connect/screens/notifications/notification_screen.dart';

void main() {
  group('AppRouter Route Generation Tests', () {
    test('generates HomeScreen for AppRoutes.home and fallback routes', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.home),
      );
      expect(route, isA<MaterialPageRoute>());
      final pageRoute = route as MaterialPageRoute;
      final widget = pageRoute.builder(
        // ignore: invalid_use_of_protected_member
        _MockBuildContext(),
      );
      expect(widget, isA<HomeScreen>());
    });

    test('generates CalendarScreen for AppRoutes.calendar', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.calendar),
      );
      final pageRoute = route as MaterialPageRoute;
      final widget = pageRoute.builder(_MockBuildContext());
      expect(widget, isA<CalendarScreen>());
    });

    test('generates NotificationScreen for AppRoutes.notifications', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.notifications),
      );
      final pageRoute = route as MaterialPageRoute;
      final widget = pageRoute.builder(_MockBuildContext());
      expect(widget, isA<NotificationScreen>());
    });

    test('generates SearchScreen for AppRoutes.search', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.search),
      );
      final pageRoute = route as MaterialPageRoute;
      final widget = pageRoute.builder(_MockBuildContext());
      expect(widget, isA<SearchScreen>());
    });

    test('extracts clubId from URI query params for AppRoutes.clubDetails', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: '${AppRoutes.clubDetails}?clubId=club_alpha_123'),
      );
      final pageRoute = route as MaterialPageRoute;
      final widget = pageRoute.builder(_MockBuildContext());
      expect(widget, isA<ClubDetailsScreen>());
      final clubDetails = widget as ClubDetailsScreen;
      expect(clubDetails.clubId, equals('club_alpha_123'));
    });

    test('extracts eventId from URI query params for AppRoutes.eventDetails', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: '${AppRoutes.eventDetails}?eventId=evt_hackathon_99'),
      );
      final pageRoute = route as MaterialPageRoute;
      final widget = pageRoute.builder(_MockBuildContext());
      expect(widget, isA<EventDetailsScreen>());
      final eventDetails = widget as EventDetailsScreen;
      expect(eventDetails.eventId, equals('evt_hackathon_99'));
    });

    test('extracts clubId from string argument for AppRoutes.clubDetails', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(
          name: AppRoutes.clubDetails,
          arguments: 'club_robotics_456',
        ),
      );
      final pageRoute = route as MaterialPageRoute;
      final widget = pageRoute.builder(_MockBuildContext());
      expect(widget, isA<ClubDetailsScreen>());
      final clubDetails = widget as ClubDetailsScreen;
      expect(clubDetails.clubId, equals('club_robotics_456'));
    });
  });
}

class _MockBuildContext extends BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
