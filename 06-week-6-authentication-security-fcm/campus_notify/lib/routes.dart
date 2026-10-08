class AppRoutes {
  static const String login = '/login';
  static const String home = '/';
  static const String announcement = '/announcement/:id';
  static String announcementDetail(String id) => '/announcement/$id';
}

String routeFromMessage(Map<String, dynamic> data) {
  final route = data['route']?.toString() ?? '/';
  if (route.isEmpty) return '/';
  return route.startsWith('/') ? route : '/$route';
}