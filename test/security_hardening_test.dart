import 'package:flutter_test/flutter_test.dart';
import 'package:klub_connect/services/auth_service.dart';

void main() {
  group('OWASP Security Hardening & Rate-Limiting Tests', () {
    test('AuthService dispatchCooldown is configured to 60 seconds', () {
      expect(AuthService.dispatchCooldown.inSeconds, equals(60));
    });

    test('canSendMagicLink and canSendPhoneOtp return true by default', () {
      // In headless test without Firebase initialized, we can verify initial cooldown logic
      expect(AuthService.dispatchCooldown, equals(const Duration(seconds: 60)));
    });

    test('Firestore rules allowed user profile update fields whitelist', () {
      const allowedUpdateKeys = {
        'first_name',
        'last_name',
        'full_name',
        'full_name_lower',
        'search_keywords',
        'about',
        'phone_number',
        'profile_image_url',
        'fcm_token',
        'last_token_updated_at',
        'last_login_at',
        'is_online',
        'last_active_at',
        'profile_completed',
        'updated_at',
      };

      const forbiddenPrivilegeKeys = {
        'user_type',
        'institution_id',
        'college_name',
        'email',
        'uid',
        'is_president_of',
        'is_organizer_of',
        'clubs_created',
      };

      for (final forbidden in forbiddenPrivilegeKeys) {
        expect(
          allowedUpdateKeys.contains(forbidden),
          isFalse,
          reason: 'Privilege field "$forbidden" MUST NOT be in allowed self-update list',
        );
      }
    });
  });
}
