import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
}

class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _client = Supabase.instance.client;

  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      debugPrint('Foreground message: ${notification.title} — ${notification.body}');
      _showInAppBanner(notification.title, notification.body);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification tapped: ${message.notification?.title}');
    });

    debugPrint('FCM listeners initialized');
  }

  static Future<void> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      final token = await _messaging.getToken();
      debugPrint('FCM Token: $token');
    }
  }

  static Future<void> subscribeToAgency(String agencyId, {String? siteId}) async {
    final token = await _messaging.getToken();
    if (token == null) {
      debugPrint('Cannot subscribe — no FCM token');
      return;
    }

    await _client.from('subscriptions').upsert(
      {
        'agency_id': agencyId,
        'fcm_token': token,
        if (siteId != null) 'site_id': siteId,
      },
      onConflict: 'agency_id,fcm_token,site_id',
    );

    debugPrint('Subscribed: agency=$agencyId site=$siteId');
  }

  static Future<void> unsubscribeFromAgency(String agencyId, {String? siteId}) async {
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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