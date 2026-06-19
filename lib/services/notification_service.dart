import 'package:flutter/foundation.dart';

/// Tracks which agency IDs the user wants to be notified about.
/// In-memory for now — will be backed by Supabase later.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final notifiedAgencyIds = ValueNotifier<Set<String>>({});

  bool isNotified(String agencyId) => notifiedAgencyIds.value.contains(agencyId);

  void toggle(String agencyId) {
    final updated = Set<String>.from(notifiedAgencyIds.value);
    updated.contains(agencyId) ? updated.remove(agencyId) : updated.add(agencyId);
    notifiedAgencyIds.value = updated;
  }
}