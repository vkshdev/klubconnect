# KlubConnect System Design and Architecture

This document provides a detailed overview of the KlubConnect application's system design and backend architecture.

## 1. Overview

KlubConnect is a mobile-first social networking platform for college communities,
built using Flutter for the cross-platform frontend and Firebase for the
backend. It enables students and faculty to manage and participate in college
clubs and events, fostering a connected campus environment. The system is
designed to be real-time, scalable, and secure, with a clear separation of
concerns between different parts of the application.

## 2. Core Technologies
### 2.1. Frontend Application (Flutter)

-   **Platform:** A single codebase for Android, iOS, and Web (with some
    features being mobile-specific).
-   **UI:** A professional and clean user interface built with Flutter widgets.
-   **State Management:** Uses the Provider package to manage application state
    in a reactive and efficient manner.
-   **Services:** A layer of service classes in the Flutter app that abstract
    the backend communication. These services are the bridge between the UI and
    Firebase.

### 2.2. Backend (Firebase)

The backend is powered by a suite of Firebase services:
-   **Firebase Authentication:** Handles all user sign-up, sign-in, and session
    management. Supports various authentication methods.
-   **Cloud Firestore:** The primary database. A NoSQL, document-based
    database that stores all the application data and provides real-time data
    synchronization.
-   **Firebase Storage:** Used for storing binary files, primarily images like
    user profile pictures, club logos, and event banners.
-   **Firebase Cloud Messaging (FCM):** Manages and sends push notifications to
    users' devices.
-   **Firebase App Check:** Provides a layer of security to ensure that requests
    to the backend are coming from legitimate instances of the app.

## 3. Architecture Block Diagram
---

The following diagram illustrates the high-level architecture of the KlubConnect system.
```
+------------------------------------------------------------------------------+
|                             KlubConnect App                                  |
|                                                                              |
|  +-----------------------+       +----------------------------------------+  |
|  |      UI Layer         |------>|             Service Layer              |  |
|  | (Screens & Widgets)   |       |                                        |  |
|  +-----------------------+       |  +----------------------------------+  |  |
|                                  |  | AuthService                      |  |  |
|                                  |  +----------------------------------+  |  |
|                                  |  | FirestoreService                 |  |  |
|                                  |  +----------------------------------+  |  |
|                                  |  | ClubService                      |  |  |
|                                  |  +----------------------------------+  |  |
|                                  |  | EventService                     |  |  |
|                                  |  +----------------------------------+  |  |
|                                  |  | ... (other services)             |  |  |
|                                  |  +----------------------------------+  |  |
|                                  +----------------------------------------+  |
+------------------------------------------|-----------------------------------+
                                           |
                                           | (HTTPS / WebSocket)
                                           |
+------------------------------------------|-----------------------------------+
|                              Firebase Backend                              |
|                                                                              |
|  +---------------------------+   +---------------------------+              |
|  | Firebase Authentication   |<->|       Cloud Firestore      |              |
|  | (Handles User Login)      |   | (NoSQL Database)           |              |
|  +---------------------------+   +---------------------------+              |
|                                                                              |
|  +---------------------------+                                              |
|  | Firebase Storage          |<--+                                          |
|  | (Image Hosting)           |   |                                          |
|  +---------------------------+   |                                          |
|                                   |                                          |
|  +---------------------------+   |                                          |
|  | Firebase Cloud Messaging  |<--+                                          |
|  | (Push Notifications)      |                                              |
|  +---------------------------+                                              |
|                                                                              |
+------------------------------------------------------------------------------+
```

## 4. Services

The backend logic is encapsulated in a set of services, each with a specific responsibility.

```
+--------------------------+
|       Service Layer      |
+--------------------------+
|  AuthService             |-----> Firebase Authentication
|  FirestoreService        |-----> Cloud Firestore
|  ClubService             |-----> Cloud Firestore, Firebase Storage
|  EventService            |-----> Cloud Firestore, Firebase Storage
|  AnnouncementService     |-----> Cloud Firestore
|  MembershipService       |-----> Cloud Firestore
|  ImageUploadService      |-----> Firebase Storage, Cloud Firestore
|  NotificationService     |-----> Firebase Cloud Messaging, Cloud Firestore
|  AuditLogService         |-----> Cloud Firestore
+--------------------------+
```

### 4.1. `AuthService`

-   **Responsibilities:** Handles all user authentication tasks.
-   **Features:**
    -   Email and password registration and login.
    -   Magic link authentication.
    -   Phone number OTP verification.
    -   Password reset functionality.
    -   User session management.
-   **Firebase Services Used:** Firebase Authentication.

### 4.2. `FirestoreService`

-   **Responsibilities:** Provides a generic interface for interacting with Cloud Firestore.
-   **Features:**
    -   Creating, reading, updating, and deleting user documents.
    -   Searching for users.
    -   Updating user presence (online/offline status).
-   **Firebase Services Used:** Cloud Firestore.

### 4.3. `ClubService`

-   **Responsibilities:** Manages all club-related operations.
-   **Features:**
    -   Creating and updating clubs.
    -   Fetching club information.
    -   Searching for clubs.
    -   Managing club members.
-   **Firebase Services Used:** Cloud Firestore, Firebase Storage (for club logos).

### 4.4. `EventService`

-   **Responsibilities:** Manages all event-related operations.
-   **Features:**
    -   Creating and updating events.
    -   Fetching event details.
    -   RSVPing to events.
    -   Managing event status (pending, approved, rejected).
-   **Firebase Services Used:** Cloud Firestore, Firebase Storage (for event banners).

### 4.5. `AnnouncementService`

-   **Responsibilities:** Manages announcements within clubs.
-   **Features:**
    -   Posting, deleting, and pinning announcements.
    -   Fetching announcements for a club.
    -   Incrementing view counts.
-   **Firebase Services Used:** Cloud Firestore.

### 4.6. `MembershipService`

-   **Responsibilities:** Manages club membership requests and roles.
-   **Features:**
    -   Sending and responding to join requests.
    -   Leaving a club.
    -   Assigning and managing roles (organizer, president).
-   **Firebase Services Used:** Cloud Firestore.

### 4.7. `ImageUploadService`

-   **Responsibilities:** Handles image uploads and compression.
-   **Features:**
    -   Compressing images before uploading to save storage and bandwidth.
    -   Uploading images to Firebase Storage.
    -   Recording asset metadata in Firestore.
-   **Firebase Services Used:** Firebase Storage, Cloud Firestore.

### 4.8. `NotificationService`

-   **Responsibilities:** Manages push notifications and in-app notifications.
-   **Features:**
    -   Sending and receiving push notifications using FCM.
    -   Displaying local notifications.
    -   Managing notification tokens.
    -   Storing and fetching in-app notifications.
-   **Firebase Services Used:** Firebase Cloud Messaging, Cloud Firestore.

### 4.9. `AuditLogService`

-   **Responsibilities:** Records important user actions for auditing and security purposes.
-   **Features:**
    -   Logs actions such as club creation, membership changes, and event status updates.
-   **Firebase Services Used:** Cloud Firestore.

## 5. Workflows

The overall workflow of the application can be summarized as follows:

```
+------------------------------------+
|            User Interface          |
|  (Flutter App - Screens/Widgets)   |
+------------------------------------+
              |
              | 1. User Interaction
              V
+------------------------------------+
|           Service Layer            |
|  (AuthService, ClubService, etc.)  |
+------------------------------------+
              |
              | 2. API Call / Data Request
              V
+------------------------------------+
|          Firebase Backend          |
| (Auth, Firestore, Storage, FCM)    |
+------------------------------------+
              |
              | 3. Data Storage / Processing / Response
              V
+------------------------------------+
|           Service Layer            |
|  (AuthService, ClubService, etc.)  |
+------------------------------------+
              |
              | 4. Data Transformation / Business Logic
              V
+------------------------------------+
|            User Interface          |
|  (Flutter App - State Update)      |
+------------------------------------+
```

### 5.1. User Registration and Login

1.  The user opens the app and navigates to the registration screen.
2.  The UI calls the `AuthService` in the Flutter app.
3.  `AuthService` communicates with **Firebase Authentication** to create a new
    user account.
4.  Upon successful creation, a new user document is created in the **Cloud
    Firestore** database via the `FirestoreService`.
5.  For logins, `AuthService` validates credentials against **Firebase
    Authentication** and fetches the user's profile from **Cloud Firestore**.

### 5.2. Creating a New Club (by a Faculty Member)

1.  A faculty member fills in the club creation form in the app.
2.  The UI calls the `ClubService`.
3.  `ClubService` initiates a "batch write" in **Cloud Firestore** to perform
    multiple operations atomically.
4.  It creates a new document in the `clubs` collection.
5.  It updates the faculty member's user document to link them to the newly
    created club.
6.  It assigns the selected student as the club's president.
7.  The batch write is committed, ensuring all changes are saved together.
8.  The `AuditLogService` records this action in an `audit_logs` collection for
    traceability.

### 5.3. Sending a Push Notification

1.  An action in the app triggers a notification (e.g., a new announcement is
    posted).
2.  The relevant service (e.g., `AnnouncementService`) calls the
    `NotificationService`.
3.  `NotificationService` saves a notification document to the **Cloud
    Firestore** `notifications` collection.
4.  For important, real-time alerts, a backend trigger (like a Firebase Function,
    not explicitly shown in the code but a standard pattern) would read this new
    document and use the **Firebase Cloud Messaging (FCM)** API to send a push
    notification to the target user's device.
5.  The user receives the notification on their device, even if the app is in the
    background.

## 6. Data Models (in Cloud Firestore)

Firestore is a NoSQL database, and the data is organized into collections of
documents.

-   **`users` collection:**
    -   Each document represents a user (student or faculty).
    -   Stores profile information, roles, and lists of clubs they are part of.

-   **`clubs` collection:**
    -   Each document represents a college club.
    -   Contains club details, a list of members, and references to its
        president and faculty mentor.
    -   Has sub-collections for `memberships` and `announcements`.

-   **`events` collection:**
    -   Each document is an event created by a club.
    -   Stores event details, date, time, location, and RSVP information.
    -   Has a sub-collection for `rsvps`.

-   **`membership_requests` collection:**
    -   Stores requests from students to join a club.

-   **`notifications` collection:**
    -   A list of in-app notifications for each user.

-   **`audit_logs` collection:**
    -   Records significant actions performed by users, for administrative
        oversight.
