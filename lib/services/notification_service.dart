import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';

import '../models/notification_model.dart';
import '../utils/constants.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize({String? userId}) async {
    // Skip notification initialization on Windows as FCM support is limited/different
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      ).timeout(const Duration(seconds: 5));

      const androidChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _localNotifications.initialize(initializationSettings);

      if (settings.authorizationStatus == AuthorizationStatus.authorized && userId != null) {
        await _saveToken(userId);
        FirebaseMessaging.instance.onTokenRefresh.listen((token) {
          _saveToken(userId, token: token);
        });
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification == null) return;
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      });
    } catch (e) {
      debugPrint('Notification Service initialization failed: $e');
    }
  }

  Future<void> _saveToken(String userId, {String? token}) async {
    final fcmToken = token ?? await _fcm.getToken();
    if (fcmToken == null) return;
    await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
      'fcm_token': fcmToken,
      'last_token_updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? fromUserId,
    String? relatedClubId,
    String? relatedEventId,
    String? actionUrl,
    String priority = 'normal',
  }) async {
    final id = const Uuid().v4();
    final notification = NotificationModel(
      notificationId: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      fromUserId: fromUserId,
      relatedClubId: relatedClubId,
      relatedEventId: relatedEventId,
      actionUrl: actionUrl,
      priority: priority,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('notifications').doc(id).set(notification.toFirestore());
  }

  Stream<List<NotificationModel>> streamNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(NotificationModel.fromFirestore).toList());
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({'is_read': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final unread = await _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }

  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
