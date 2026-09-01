<p align="center">
  <img src="assets/images/logo.png" width="90" alt="KlubConnect Logo">
</p>

<h1 align="center">KlubConnect</h1>

<p align="center">
  <strong>College clubs should not run on group chats and spreadsheets.</strong>
</p>

<p align="center">
  <a href="#why-it-exists">Why It Exists</a> &nbsp;·&nbsp;
  <a href="#what-it-does">What It Does</a> &nbsp;·&nbsp;
  <a href="#key-features">Key Features</a> &nbsp;·&nbsp;
  <a href="#tech-stack">Tech Stack</a> &nbsp;·&nbsp;
  <a href="ARCHITECTURE.md">Architecture</a> &nbsp;·&nbsp;
  <a href="BACKEND_DESIGN.md">Backend Design</a>
</p>

---

## Why It Exists

Every college has clubs. Most of them are disorganized.

Event announcements get buried in WhatsApp threads. Membership requests are tracked in Excel sheets. Students miss events they would have attended because they never heard about them. Faculty mentors have no visibility into what their clubs are doing. Organizers send the same message to five different platforms and still reach half the audience.

KlubConnect provides dedicated infrastructure for campus organization. It replaces fragmented communication with structured, real-time tools built specifically for higher education institutions — featuring institutional domain verification, role-based governance, transactional event capacity, and multi-tenant security isolation.

---

## What It Does

KlubConnect handles the complete lifecycle of college community operations:

### For Students
- Discover clubs across campus filtered by category, interest, and keyword indexing.
- Submit membership requests and track approval decisions in real time.
- RSVP to campus events with live participant counts updated through transactional cloud workers.
- Receive targeted push notifications for club announcements and membership updates.
- View a unified calendar of approved institutional events.

### For Club Leaders & Presidents
- Propose events and route them through formal faculty mentor approval workflows.
- Post and pin announcements to all verified club members.
- Manage member rosters and assign organizer roles with full audit accountability.
- Monitor live event check-ins and capacity metrics.

### For Faculty Mentors
- Govern student clubs with institutional authority verified through domain checks or invite codes.
- Review, approve, or reject event proposals before public campus publishing.
- Maintain comprehensive oversight of member activities through append-only audit logs.
- Single source of truth for all student organizations under their mentorship.

---

## Key Features

- **Multi-Tenant Campus Isolation**: Strict multi-tenant partitioning ensures every query and document is scoped to an immutable `institution_id`.
- **Dual-Mode Faculty Verification**: Faculty status is verified automatically via institutional email domain whitelist matching or through authorized invite codes, defaulting unverified users to `pending_verification`.
- **Account Status Gating**: Visual onboarding status banners guide unverified faculty on `HomeScreen`, while club creation and event approvals remain gated until verification is active.
- **Zero-Trust Security Lockdown**: Client update permissions for role arrays (`is_president_of`, `is_organizer_of`, `clubs_joined`, `clubs_created`) are strictly removed in `firestore.rules`. User document updates are restricted to a whitelist of 15 safe profile fields.
- **Modern UI**: Polished presentation layer featuring custom `Panel` containers, Material 3 theming, and a centralized theme-aware `AppSnackBar` with semantic variants (`success`, `error`, `warning`, `info`).
- **Asynchronous Go Backend Worker**: Serverless microservice on Google Cloud Run triggered by GCP Eventarc CloudEvents (v1.0) handling atomic membership batches, transactional RSVP delta calculations, multicast FCM push notifications, and tamper-proof audit trails.
- **Comprehensive Observability**: Full instrumentation with Firebase Performance Monitoring, Firebase Remote Config, Firebase Crashlytics, Firebase Analytics, and Firebase App Check (Play Integrity & App Attest).

---

## Tech Stack

| Layer | Technology | Description |
|---|---|---|
| **Mobile Client** | Flutter (Dart 3.x) | Cross-platform client for Android, iOS, and Web |
| **State Management** | Provider | ViewModel architecture and stream lifecycle management |
| **Authentication** | Firebase Auth | Email/Password, Magic Link, and Phone OTP |
| **Database** | Cloud Firestore | Multi-tenant NoSQL document database partitioned by `institution_id` |
| **Media Storage** | Firebase Storage | Profile images and event banners with `storage_assets` indexing |
| **Push Notifications** | Firebase Cloud Messaging | Multicast push notifications via HTTP v1 API |
| **Device Attestation** | Firebase App Check | Play Integrity (Android) and App Attest (iOS) |
| **Performance Monitoring** | `firebase_performance: ^0.10.1` | Network latency, trace monitoring, and UI render metrics |
| **Feature Configuration** | `firebase_remote_config: ^5.3.4` | Dynamic feature flags, runtime thresholds, and kill switches |
| **Crash Reporting** | `firebase_crashlytics: ^5.0.4` | Real-time crash diagnostics and stack trace aggregation |
| **Product Analytics** | `firebase_analytics: ^12.0.3` | User onboarding funnels and engagement metrics |
| **Event Routing** | GCP Eventarc | Firestore triggers delivered as CloudEvents v1.0 |
| **Backend Microservice**| Go 1.22 on Google Cloud Run | Server-side atomic batch processing and idempotency guards |
| **Secret Management** | GCP Secret Manager | Production credentials and runtime secrets |

---

---

## License

This project is licensed under the [MIT License](LICENSE).
