import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'fcm_service.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final notifiedAgencyIds = ValueNotifier<Set<String>>({});

  bool isNotified(String agencyId) => notifiedAgencyIds.value.contains(agencyId);

  /// Load subscriptions from Supabase on app start
  Future<void> loadFromSupabase() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final rows = await Supabase.instance.client
        .from('subscriptions')
        .select('agency_id')
        .eq('fcm_token', token);

    final ids = (rows as List).map((r) => r['agency_id'] as String).toSet();
    notifiedAgencyIds.value = ids;
    debugPrint('Loaded ${ids.length} subscriptions from Supabase');
  }

  Future<void> toggle(String agencyId, {String? siteId}) async {
    final updated = Set<String>.from(notifiedAgencyIds.value);
    if (updated.contains(agencyId)) {
      updated.remove(agencyId);
      await FcmService.unsubscribeFromAgency(agencyId, siteId: siteId);
    } else {
      updated.add(agencyId);
      await FcmService.subscribeToAgency(agencyId, siteId: siteId);
    }
    notifiedAgencyIds.value = updated;
  }
}