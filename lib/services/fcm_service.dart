import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _client = Supabase.instance.client;

  static Future<void> init() async {
    await _messaging.requestPermission();

    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('Foreground message: ${message.notification?.title}');
    });
  }

  static Future<void> subscribeToAgency(String agencyId) async {
    final token = await _messaging.getToken();
    if (token == null) return;

    await _client.from('subscriptions').upsert({
      'agency_id': agencyId,
      'fcm_token': token,
    });
    debugPrint('Subscribed to $agencyId');
  }

  static Future<void> unsubscribeFromAgency(String agencyId) async {
    final token = await _messaging.getToken();
    if (token == null) return;

    await _client.from('subscriptions')
        .delete()
        .eq('agency_id', agencyId)
        .eq('fcm_token', token);
    debugPrint('Unsubscribed from $agencyId');
  }
}