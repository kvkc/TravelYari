import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_service.dart';

enum NotificationType {
  tripUpdated,
  participantJoined,
  participantLeft,
  tripShared,
  general,
}

class TripNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String? tripId;
  final DateTime receivedAt;
  final bool isRead;

  TripNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.tripId,
    DateTime? receivedAt,
    this.isRead = false,
  }) : receivedAt = receivedAt ?? DateTime.now();

  TripNotification copyWith({bool? isRead}) {
    return TripNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      tripId: tripId,
      receivedAt: receivedAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

class NotificationState {
  final List<TripNotification> notifications;
  final int unreadCount;
  final String? fcmToken;
  final bool isInitialized;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.fcmToken,
    this.isInitialized = false,
  });

  NotificationState copyWith({
    List<TripNotification>? notifications,
    int? unreadCount,
    String? fcmToken,
    bool? isInitialized,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      fcmToken: fcmToken ?? this.fcmToken,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class NotificationService extends StateNotifier<NotificationState> {
  final FirebaseMessaging? _messaging;
  StreamSubscription? _foregroundSubscription;

  NotificationService()
      : _messaging =
            FirebaseService.isAvailable ? FirebaseMessaging.instance : null,
        super(const NotificationState());

  /// Initialize notification service
  Future<void> initialize() async {
    if (_messaging == null) {
      debugPrint('Firebase Messaging not available');
      return;
    }

    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Push notifications authorized');

        // Get FCM token
        final token = await _messaging.getToken();
        state = state.copyWith(fcmToken: token, isInitialized: true);
        debugPrint('FCM Token: $token');

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          state = state.copyWith(fcmToken: newToken);
          debugPrint('FCM Token refreshed: $newToken');
        });

        // Handle foreground messages
        _foregroundSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background/terminated app messages
        FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

        // Handle notification tap when app is in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Check if app was opened from a notification
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }
      } else {
        debugPrint('Push notifications not authorized');
      }
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Received foreground message: ${message.messageId}');

    final notification = _parseNotification(message);
    if (notification != null) {
      _addNotification(notification);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    // Navigation handling would go here
    // This would typically use a navigation service or global key
  }

  TripNotification? _parseNotification(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;

    if (notification == null) return null;

    NotificationType type = NotificationType.general;
    if (data['type'] != null) {
      type = NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.general,
      );
    }

    return TripNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: notification.title ?? 'Travel Yaari',
      body: notification.body ?? '',
      tripId: data['tripId'],
    );
  }

  void _addNotification(TripNotification notification) {
    final updatedNotifications = [notification, ...state.notifications];
    // Keep only last 50 notifications
    if (updatedNotifications.length > 50) {
      updatedNotifications.removeRange(50, updatedNotifications.length);
    }

    state = state.copyWith(
      notifications: updatedNotifications,
      unreadCount: state.unreadCount + 1,
    );
  }

  /// Mark a notification as read
  void markAsRead(String notificationId) {
    final updatedNotifications = state.notifications.map((n) {
      if (n.id == notificationId && !n.isRead) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    final newUnreadCount = updatedNotifications.where((n) => !n.isRead).length;

    state = state.copyWith(
      notifications: updatedNotifications,
      unreadCount: newUnreadCount,
    );
  }

  /// Mark all notifications as read
  void markAllAsRead() {
    final updatedNotifications = state.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();

    state = state.copyWith(
      notifications: updatedNotifications,
      unreadCount: 0,
    );
  }

  /// Clear all notifications
  void clearAll() {
    state = state.copyWith(
      notifications: [],
      unreadCount: 0,
    );
  }

  /// Subscribe to a topic (e.g., trip updates)
  Future<void> subscribeToTopic(String topic) async {
    if (_messaging == null) return;

    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Failed to subscribe to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (_messaging == null) return;

    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Failed to unsubscribe from topic: $e');
    }
  }

  /// Subscribe to trip updates
  Future<void> subscribeToTripUpdates(String tripId) async {
    await subscribeToTopic('trip_$tripId');
  }

  /// Unsubscribe from trip updates
  Future<void> unsubscribeFromTripUpdates(String tripId) async {
    await unsubscribeFromTopic('trip_$tripId');
  }

  @override
  void dispose() {
    _foregroundSubscription?.cancel();
    super.dispose();
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  debugPrint('Received background message: ${message.messageId}');
  // Background processing can be done here
  // Note: This runs in a separate isolate, so state updates won't be visible
}

// Providers
final notificationServiceProvider =
    StateNotifierProvider<NotificationService, NotificationState>((ref) {
  final service = NotificationService();
  service.initialize();
  return service;
});

// Convenience providers
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationServiceProvider).unreadCount;
});

final notificationsProvider = Provider<List<TripNotification>>((ref) {
  return ref.watch(notificationServiceProvider).notifications;
});
