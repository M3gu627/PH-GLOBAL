import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
}

class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _client = Supabase.instance.client;

  // ── Refresh callbacks ─────────────────────────────────────────────────────
  //
  // Any screen can register itself here. When a notification arrives for
  // a given agency_id, all matching callbacks are fired so the screen
  // re-fetches fresh data from Supabase.
  //
  // Usage in a screen:
  //   FcmService.registerRefreshCallback('dfa', _refreshData);
  //   // and in dispose():
  //   FcmService.unregisterRefreshCallback('dfa', _refreshData);

  static final _refreshCallbacks = <String, List<VoidCallback>>{};

  static void registerRefreshCallback(String agencyId, VoidCallback callback) {
    _refreshCallbacks.putIfAbsent(agencyId, () => []).add(callback);
    debugPrint('FCM: registered refresh callback for $agencyId');
  }

  static void unregisterRefreshCallback(String agencyId, VoidCallback callback) {
    _refreshCallbacks[agencyId]?.remove(callback);
    debugPrint('FCM: unregistered refresh callback for $agencyId');
  }

  static void _triggerRefresh(String? agencyId) {
    if (agencyId == null) return;
    final callbacks = _refreshCallbacks[agencyId];
    if (callbacks == null || callbacks.isEmpty) {
      debugPrint('FCM: no refresh callbacks registered for $agencyId');
      return;
    }
    debugPrint('FCM: triggering ${callbacks.length} refresh callback(s) for $agencyId');
    for (final cb in List.of(callbacks)) {
      cb();
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground notification — show banner AND refresh the open screen
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final agencyId = message.data['agency_id'] as String?;

      debugPrint('Foreground message: ${notification?.title} | agency=$agencyId');

      // 1. Refresh the currently open agency detail screen (if it matches)
      _triggerRefresh(agencyId);

      // 2. Show in-app banner
      if (notification != null) {
        _showInAppBanner(notification.title, notification.body);
      }
    });

    // Tapped notification while app was in background — also refresh
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final agencyId = message.data['agency_id'] as String?;
      debugPrint('Notification tapped: ${message.notification?.title} | agency=$agencyId');
      _triggerRefresh(agencyId);
    });

    debugPrint('FCM listeners initialized');
  }

  // ── Permission & token ────────────────────────────────────────────────────

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

  // ── Subscribe / Unsubscribe ───────────────────────────────────────────────

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
        'site_id': siteId,
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

  // ── In-app banner ─────────────────────────────────────────────────────────

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
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
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