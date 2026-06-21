import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles background messages (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are shown automatically by FCM on Android/iOS.
  // Nothing extra needed here — just ensure Firebase is initialized.
  debugPrint('Background message: ${message.notification?.title}');
}

class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _client = Supabase.instance.client;

  /// Call once at startup — sets up listeners but does NOT request permission.
  /// Permission is requested separately via [requestPermission] after splash.
  static Future<void> init() async {
    // Register background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground messages — show a snackbar-style in-app banner
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      debugPrint('Foreground message: ${notification.title} — ${notification.body}');

      // Show an in-app overlay notification since the OS won't show a banner
      // while the app is in the foreground.
      _showInAppBanner(notification.title, notification.body);
    });

    // When user taps a notification while app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification tapped: ${message.notification?.title}');
      // TODO: navigate to the relevant agency screen when tapped
    });

    debugPrint('FCM listeners initialized');
  }

  /// Request OS notification permission — call this after splash screen.
  /// Safe to call multiple times; iOS only prompts once.
  static Future<void> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false, // true = silent delivery on iOS without prompting
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Permission granted — log the token for debugging
      final token = await _messaging.getToken();
      debugPrint('FCM Token: $token');
    }
  }

  /// Subscribe to notifications for a specific agency + site.
  /// For DFA: siteId is the DFA location ID (e.g. "489" for Malolos/Xentro Mall).
  /// The scraper will ONLY notify tokens that match the exact agency_id + site_id pair.
  static Future<void> subscribeToAgency(
    String agencyId, {
    String? siteId,
  }) async {
    final token = await _messaging.getToken();
    if (token == null) {
      debugPrint('Cannot subscribe — no FCM token');
      return;
    }

    final payload = <String, dynamic>{
      'agency_id': agencyId,
      'fcm_token': token,
      if (siteId != null) 'site_id': siteId,
    };

    await _client.from('subscriptions').upsert(
      payload,
      onConflict: 'agency_id,fcm_token,site_id',
    );

    debugPrint('Subscribed: agency=$agencyId site=$siteId');
  }

  /// Unsubscribe from notifications for a specific agency + site.
  static Future<void> unsubscribeFromAgency(
    String agencyId, {
    String? siteId,
  }) async {
    final token = await _messaging.getToken();
    if (token == null) return;

    var query = _client
        .from('subscriptions')
        .delete()
        .eq('agency_id', agencyId)
        .eq('fcm_token', token);

    if (siteId != null) query = query.eq('site_id', siteId);
    await query;

    debugPrint('Unsubscribed: agency=$agencyId site=$siteId');
  }

  /// Shows a temporary in-app banner for foreground notifications.
  /// Uses a global overlay so it works from any screen.
  static final _overlayKey = GlobalKey<NavigatorState>();

  static GlobalKey<NavigatorState> get navigatorKey => _overlayKey;

  static void _showInAppBanner(String? title, String? body) {
    final context = _overlayKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            if (body != null)
              Text(body, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF8B5CF6),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}