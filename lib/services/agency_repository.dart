import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/agency.dart';

class AgencyRepository {
  static final _client = Supabase.instance.client;

  static Future<List<Agency>> fetchAgencies() async {
    final agenciesData = await _client.from('agencies').select();
    debugPrint('Fetched ${agenciesData.length} agencies: $agenciesData');

    final slotsData = await _client.from('slots').select();
    debugPrint('Fetched ${slotsData.length} slots: $slotsData');

    return agenciesData.map((row) {
      final dates = slotsData
          .where((s) => s['agency_id'] == row['id'])
          .map((s) => DateTime.parse(s['slot_date'] as String))
          .toList();

      return Agency(
        id: row['id'],
        name: row['name'],
        description: row['description'] ?? '',
        websiteUrl: row['website_url'],
        icon: _iconFromName(row['icon_name']),
        availableDates: dates,
      );
    }).toList();
  }

  static IconData _iconFromName(String name) {
    switch (name) {
      case 'flight_takeoff': return Icons.flight_takeoff;
      case 'fingerprint': return Icons.fingerprint;
      case 'local_hospital': return Icons.local_hospital;
      default: return Icons.business;
    }
  }
}