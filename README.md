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
  <a href="#who-it-is-for">Who It Is For</a> &nbsp;·&nbsp;
  <a href="#tech-stack">Tech Stack</a> &nbsp;·&nbsp;
  <a href="ARCHITECTURE.md">Architecture</a>
</p>

---

## Why It Exists

Every college has clubs. Most of them are disorganized.

Event announcements get buried in WhatsApp threads. Membership requests are tracked in Excel sheets. Students miss events they would have attended because they never heard about them. Faculty mentors have no visibility into what their clubs are doing. Organizers send the same message to five different platforms and still reach half the audience.

KlubConnect exists because the infrastructure for college community life has not kept pace with how students actually communicate and organize. It is a purpose-built platform that replaces ad-hoc coordination with structured, real-time tools — built specifically for the college context, not repurposed from corporate software.

---

## What It Does

KlubConnect is a full-stack college club and event management platform. It handles the complete lifecycle of college community life — from the moment a faculty member creates a club to the moment a student receives a push notification that their membership has been approved.

### For Students

- Discover every club at their college, filtered by category and interest.
- Submit membership requests and track approval status in real time.
- RSVP to events with live participant counts that update instantly.
- Receive push notifications for events, announcements, and membership decisions.
- View a unified calendar of all approved college events — no hunting across platforms.

### For Club Leaders

- Propose events and route them through the faculty approval workflow.
- Post and pin announcements to all club members.
- Manage member roles — promote organizers, assign presidents — with full audit history.
- Monitor real-time RSVP counts without spreadsheets.

### For Faculty

- Create and govern clubs with institutional authority.
- Approve or reject event proposals before they go public.
- Maintain full oversight of member activity through an audit log.
- A single source of truth for every club they mentor.

---

## Who It Is For

KlubConnect is designed for colleges where student life is active but disorganized — where clubs exist but the infrastructure does not, where events happen but communication breaks down, and where faculty want oversight without bureaucratic overhead.

It is not a generic social network. It does not try to replicate what exists. It is scoped, purposeful, and built around the specific workflows that college communities actually need.

---

## App Preview

<p align="center">
  <img src="assets/screenshots/Sign_in.png" width="250" alt="Sign In Screen">
  <img src="assets/screenshots/Students.png" width="250" alt="Student Home Screen">
  <img src="assets/screenshots/Faculty.png" width="250" alt="Faculty Home Screen">
</p>

---

## Tech Stack

KlubConnect is built on a hybrid architecture — a Flutter mobile app for real-time user interaction, Firebase BaaS for data and authentication, and a Go microservice on Google Cloud Run for server-critical, high-concurrency operations.

| Layer | Technology |
|---|---|
| Mobile App | Flutter (Dart) — Android, iOS, Web |
| State Management | Provider |
| Database | Cloud Firestore — real-time, multi-tenant NoSQL |
| File Storage | Firebase Storage |
| Authentication | Firebase Auth — Email, Magic Link, OTP |
| Device Security | Firebase App Check — Play Integrity / App Attest |
| Push Notifications | Firebase Cloud Messaging |
| Event Bus | GCP Eventarc — Firestore triggers to CloudEvent HTTP |
| Backend Workers | Go 1.22 on Google Cloud Run — scale-to-zero |
| Secret Management | GCP Secret Manager |

The Go backend is not a wrapper around Firebase. It exists to solve specific production problems that a mobile client cannot safely or reliably handle on its own.

- **Audit logs** written server-side so they cannot be forged by a modified client.
- **FCM dispatch** handled asynchronously with stale token cleanup and multi-device fan-out.
- **RSVP counters** aggregated through Firestore Transactions to survive concurrent write storms during large events.
- **Membership approvals** committed as atomic batched writes across multiple collections so a client crash cannot leave data in a partial state.

Every Go handler uses a CloudEvent ID idempotency guard backed by a `go_worker_state` Firestore collection, ensuring at-least-once Eventarc delivery does not produce duplicate side effects.

---

## Security

Security is enforced at every layer, not just at the application level.

- **Multi-tenant isolation**: Every Firestore read and write is scoped to the user's verified `institution_id`. A student at one college cannot access any data from another.
- **Role-Based Access Control**: Club creation is restricted to faculty users at the Firestore rule level — not just the UI. Event approval is restricted to the club master. These rules are enforced server-side and cannot be bypassed.
- **Immutable records**: Audit logs and idempotency state cannot be modified or deleted by any client credential. They are owned exclusively by the Go backend worker.
- **Device attestation**: Firebase App Check with Play Integrity (Android) and App Attest (iOS) ensures only genuine app instances can talk to the backend.

---

## Architecture

For the full system architecture — see [ARCHITECTURE.md](ARCHITECTURE.md).

For Go backend handler specifications, trigger contracts, and the membership approval sequence diagram, see [BACKEND_DESIGN.md](BACKEND_DESIGN.md).

---

## License

This project is licensed under the [MIT License](LICENSE).
