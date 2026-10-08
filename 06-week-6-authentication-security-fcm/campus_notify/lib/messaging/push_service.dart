import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../routes.dart';

final _local = FlutterLocalNotificationsPlugin();
void Function(String route)? _onRouteTap;

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'high_importance_channel',
  'Campus Announcements',
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Do not touch BuildContext / Riverpod here.
  // Job: log / persist lightly. Navigation happens on click.
  debugPrint('Handling background message: ${message.messageId}');
}

void registerBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

Future<void> initFcmToken({
  required Future<void> Function(String token) onToken,
}) async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    debugPrint('==================================================');
    debugPrint('FCM TOKEN: $token');
    debugPrint('==================================================');
    await onToken(token);
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    debugPrint('FCM TOKEN REFRESHED: $newToken');
    onToken(newToken);
  });

  await FirebaseMessaging.instance.subscribeToTopic('campus-announcement');
}

Future<bool> requestNotificationPermission() async {
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true, badge: true, sound: true,
    announcement: false, carPlay: false, criticalAlert: false,
  );
  return settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}

Future<void> initLocalNotifications({void Function(String route)? onNavigate}) async {
  if (onNavigate != null) _onRouteTap = onNavigate;
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();

  await _local.initialize(
    settings: const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (response) {
      if (response.payload != null) {
        pendingDeepLink = response.payload;
        _onRouteTap?.call(response.payload!);
      }
    },
  );

  final androidPlugin = _local.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(_channel);
  }

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
}

void listenForeground(void Function(String route) go) {
  _onRouteTap = go;
  // Foreground: the system shows NO banner automatically,
  // so display one manually via a local notification.
  FirebaseMessaging.onMessage.listen((message) async {
    final route = routeFromMessage(message.data);
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'Campus Announcements',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    await _local.show(
      id: message.hashCode,
      title: message.notification?.title ?? 'Announcement',
      body: message.notification?.body ?? '',
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: route,
    );
  });

  // Background -> tapped.
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    final route = routeFromMessage(message.data);
    go(route);
  });
}

Future<void> handleTerminated(void Function(String route) go) async {
  // Terminated -> opened from a notification.
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) {
    final route = routeFromMessage(initial.data);
    go(route);
  } else if (pendingDeepLink != null) {
    go(pendingDeepLink!);
    pendingDeepLink = null;
  }
}

Future<void> subscribeToTopic(String topic) async {
  await FirebaseMessaging.instance.subscribeToTopic(topic);
}

Future<void> unsubscribeFromTopic(String topic) async {
  await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
}

String? pendingDeepLink;