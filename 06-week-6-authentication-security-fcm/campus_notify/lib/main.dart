import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'pages/announcement_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'providers/auth_provider.dart';
import 'messaging/push_service.dart';
import 'routes.dart';

final container = ProviderContainer();

final router = GoRouter(
  redirect: (context, state) {
    final loggedIn = container.read(authStateProvider).value ?? false;
    final goingLogin = state.matchedLocation == AppRoutes.login;
    final goingAnnouncement = state.matchedLocation.startsWith('/announcement/');
    if (!loggedIn && !goingLogin && !goingAnnouncement) return AppRoutes.login;
    if (loggedIn && goingLogin) return AppRoutes.home;
    return null;
  },
  routes: [
    GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
    GoRoute(path: AppRoutes.home, builder: (_, _) => const HomePage()),
    GoRoute(
      path: AppRoutes.announcement,
      builder: (_, state) => AnnouncementPage(
        id: state.pathParameters['id'] ?? '',
      ),
    ),
  ],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  registerBackgroundHandler();

  await requestNotificationPermission();
  await initLocalNotifications(onNavigate: (route) {
    router.go(route);
  });
  await initFcmToken(onToken: (token) async {
    debugPrint('FCM Registration Token: $token');
  });

  listenForeground((route) {
    router.go(route);
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );

  // Handle deep link from terminated or initial notification state after app builds
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await handleTerminated((route) {
      router.go(route);
    });
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Campus Notify',
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
    );
  }
}