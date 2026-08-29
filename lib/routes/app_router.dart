import 'package:flutter/material.dart';

import '../models/club_model.dart';
import '../models/user_model.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/registration_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/clubs/announcement_list_screen.dart';
import '../screens/clubs/club_details_screen.dart';
import '../screens/clubs/club_list_screen.dart';
import '../screens/clubs/create_club_screen.dart';
import '../screens/events/create_event_screen.dart';
import '../screens/events/event_details_screen.dart';
import '../screens/home/calendar_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/search_screen.dart';
import '../screens/notifications/notification_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import 'app_routes.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static BuildContext? get currentContext => navigatorKey.currentContext;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final uri = Uri.tryParse(settings.name ?? '') ?? Uri(path: AppRoutes.home);
    final path = uri.path;
    final queryParams = uri.queryParameters;
    final args = settings.arguments;

    Widget page;

    switch (path) {
      case AppRoutes.initial:
      case AppRoutes.home:
        page = const HomeScreen();
        break;

      case AppRoutes.welcome:
        page = const WelcomeScreen();
        break;

      case AppRoutes.login:
        page = const LoginScreen();
        break;

      case AppRoutes.register:
        final userType = args is String ? args : queryParams['userType'];
        page = RegistrationScreen(userType: userType ?? 'student');
        break;

      case AppRoutes.calendar:
        page = const CalendarScreen();
        break;

      case AppRoutes.notifications:
        page = const NotificationScreen();
        break;

      case AppRoutes.search:
        page = const SearchScreen();
        break;

      case AppRoutes.clubList:
        page = const ClubListScreen();
        break;

      case AppRoutes.clubDetails:
        String clubId = '';
        if (args is String) {
          clubId = args;
        } else if (args is Map && args['clubId'] != null) {
          clubId = args['clubId'].toString();
        } else if (queryParams['clubId'] != null) {
          clubId = queryParams['clubId']!;
        } else if (queryParams['id'] != null) {
          clubId = queryParams['id']!;
        }
        page = ClubDetailsScreen(clubId: clubId);
        break;

      case AppRoutes.createClub:
        page = const CreateClubScreen();
        break;

      case AppRoutes.eventDetails:
        String eventId = '';
        if (args is String) {
          eventId = args;
        } else if (args is Map && args['eventId'] != null) {
          eventId = args['eventId'].toString();
        } else if (queryParams['eventId'] != null) {
          eventId = queryParams['eventId']!;
        } else if (queryParams['id'] != null) {
          eventId = queryParams['id']!;
        }
        page = EventDetailsScreen(eventId: eventId);
        break;

      case AppRoutes.createEvent:
        if (args is ClubModel) {
          page = CreateEventScreen(club: args);
        } else {
          page = const HomeScreen();
        }
        break;

      case AppRoutes.profile:
        if (args is UserModel) {
          page = EditProfileScreen(user: args);
        } else {
          page = const HomeScreen();
        }
        break;

      case AppRoutes.announcements:
        if (args is Map<String, dynamic>) {
          page = AnnouncementListScreen(
            clubId: args['clubId']?.toString() ?? '',
            clubName: args['clubName']?.toString() ?? 'Club Announcements',
            canPost: args['canPost'] == true,
          );
        } else {
          page = const HomeScreen();
        }
        break;

      default:
        page = const HomeScreen();
        break;
    }

    return MaterialPageRoute(
      builder: (_) => page,
      settings: settings,
    );
  }

  static Future<T?> push<T extends Object?>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState?.pushNamed<T>(
      routeName,
      arguments: arguments,
    ) ?? Future.value(null);
  }

  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    String routeName, {
    Object? arguments,
    TO? result,
  }) {
    return navigatorKey.currentState?.pushReplacementNamed<T, TO>(
      routeName,
      arguments: arguments,
      result: result,
    ) ?? Future.value(null);
  }

  static void pop<T extends Object?>([T? result]) {
    navigatorKey.currentState?.pop<T>(result);
  }

  static Future<void> navigateToClub(String clubId) async {
    await push(AppRoutes.clubDetails, arguments: clubId);
  }

  static Future<void> navigateToEvent(String eventId) async {
    await push(AppRoutes.eventDetails, arguments: eventId);
  }
}
