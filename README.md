
# KlubConnect

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Firebase](https://img.shields.io/badge/Firebase-Integrated-orange.svg)
![Status](https://img.shields.io/badge/Status-Complete-success.svg)

**Connect through your clubs and build your community**

KlubConnect is a comprehensive college club management and social networking platform built with Flutter and Firebase, designed to simplify communication, club engagement, and event management for students and faculty.

---

## **Project Phases Completed**

### **Phase 1 - Authentication and Basic User Module**
- **User Authentication**: Email/Password and Phone OTP (Firebase)
- **Student and Faculty Registration**: Multi-page registration forms with validation
- **Profile Setup**: Profile image upload and detailed user information
- **Glass Morphism UI**: Modern, transparent design language used throughout the app

### **Phase 2 - Clubs and Events Management**
- **Club Management**: Faculty can create clubs; Students can browse and join clubs
- **Event Workflow**: Presidents/Organizers can propose events for approval by Club Masters
- **RSVP System**: Students can RSVP (Yes, Interested, No) with real-time participant counts
- **Membership Management**: Role assignment (Club Master, President, Organizer) and join request approvals

### **Phase 3 - Calendar, Notifications and Announcements**
- **Event Calendar**: Monthly/Weekly view for tracking all approved college events
- **Announcements**: Club leaders can post and pin important announcements
- **Global Search**: Search for clubs, events, and users with integrated filters
- **Notifications**: In-app and push notifications for join requests, event approvals, and more
- **Profile Enhancements**: Edit profile screen with privacy controls for enrollment visibility

---

## **Tech Stack**
- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Auth, Firestore, Storage, Messaging)
- **State Management**: Provider
- **Design System**: Custom Glass Morphism UI

---

## **Installation and Setup**

1. **Clone the repository**:
   ```sh
   git clone https://github.com/vikashmehta292511/klubconnect.git
   ```

2. **Install dependencies**:
   ```sh
   flutter pub get
   ```

3. **Firebase Configuration**:
   - Add your google-services.json to android/app/
   - Deploy Firestore and Storage rules using Firebase CLI:
     ```sh
     firebase deploy --only firestore,storage
     ```

4. **Run the app**:
   ```sh
   flutter run
   ```

---

## **Security Features**
- **Role-Based Access Control (RBAC)**: Enforced via Firestore Security Rules
- **Input Sanitization**: All user inputs are trimmed and cleaned to prevent injection
- **Strict Validation**: Comprehensive form validation for all critical user actions
- **Secure File Storage**: Individual and club-level storage permissions
