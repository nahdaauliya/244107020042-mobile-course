// Parsing rute kini tinggal di core/format.dart (fungsi murni, mudah diuji).
// Diekspor ulang agar import lama tetap kompatibel.
export 'core/format.dart' show routeFromMessage;

class AppRoutes {
  static const String login = '/login';
  static const String home = '/';
  static const String notes = '/notes';
  static const String announcement = '/announcement/:id';
  static String announcementDetail(String id) => '/announcement/$id';
}
