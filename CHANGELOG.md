# Changelog

All notable changes to the KlubConnect project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0] - 2026-08-30

### Added
- **Multi-Tenant College Isolation**: Strict tenant scoping across all collections using verified `institution_id` domain mappings.
- **Go Microservice Worker**: Eventarc-triggered Cloud Run backend worker handling atomic membership approvals, transactional RSVP counters, and server-managed audit trails.
- **Enterprise Design System**: Shared foundation (`ScreenBackground`, `GlassPanel`, `IconGlassButton`, `ScreenHeader`, `CachedRemoteImage`) applied uniformly across all 7 secondary application screens.
- **AppRouter & Deep Linking**: Centralized named routing architecture supporting query parameters and push notification intent routing.
- **Security Hardening**:
  - Privilege escalation lockdowns on Firestore `users` self-updates.
  - Immutability guards on club ownership and institution metadata.
  - OWASP security headers (`nosniff`, `DENY`, `HSTS`) and 2MB payload size limits in Go backend.
  - Rate-limiting (60-second cooldown) on magic link and SMS OTP dispatch.
- **Observability & Resilience**:
  - Integrated `firebase_crashlytics` and `firebase_analytics` with fatal error capture and `PlatformDispatcher` error handlers.
  - Custom glassmorphic `_GlobalErrorFallback` boundary replacing default red error screens in release builds.
  - `.env.example`, `.firebaserc`, and `firestore.indexes.json` composite indexes.
- **Automated CI/CD**: Multi-tier GitHub Actions workflow running Flutter static analysis, Dart unit and widget test suites, and Go race-detector test suites.

### Changed
- Migrated legacy array-based member tracking to infinite-scale subcollection architecture (`clubs/{clubId}/memberships` and `users/{userId}/club_memberships`).
- Replaced direct `Image.network` calls with `CachedRemoteImage` featuring shimmer placeholders and disk cache management.
- Hardened Stream subscriptions across `CalendarScreen` and search views to guarantee resource disposal on unmount.

---

## [1.0.0] - Initial Release

- Initial student and faculty authentication.
- Club discovery, event listings, and basic join request workflows.
