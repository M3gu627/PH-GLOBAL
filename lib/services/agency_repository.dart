import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/agency.dart';

const _dfaSiteNames = {
  '10': 'Angeles (SM City Clark)',
  '486': 'Antipolo (SM Center)',
  '693': 'Antique (CityMall)',
  '11': 'Bacolod (Robinsons)',
  '12': 'Baguio (SM City)',
  '703': 'Balanga (The Bunker Building)',
  '14': 'Butuan (Robinsons)',
  '15': 'Cagayan De Oro (BPO Tower)',
  '16': 'Calasiao (Robinsons)',
  '702': 'Candon (Candon City Arena)',
  '17': 'Cebu (Robinsons Galleria)',
  '487': 'Clarin (Town Center)',
  '4': 'DFA Manila (Aseana)',
  '5': 'NCR Central (Robinsons Galleria Ortigas)',
  '6': 'NCR East (SM Megamall)',
  '423': 'NCR North (Robinsons Novaliches)',
  '7': 'NCR Northeast (Ali Mall Cubao)',
  '704': 'NCR South (Festival Mall)',
  '9': 'NCR West (SM City Manila)',
  '488': 'Dasmarinas (SM City)',
  '19': 'Davao (SM City)',
  '20': 'Dumaguete (Robinsons)',
  '21': 'General Santos (Robinsons)',
  '22': 'Iloilo (Robinsons)',
  '690': 'Kidapawan',
  '23': 'La Union (CSI Mall)',
  '24': 'Legazpi (Pacific Mall)',
  '13': 'Lipa (Robinsons)',
  '25': 'Lucena (Pacific Mall)',
  '489': 'Malolos (Xentro Mall)',
  '705': 'Olongapo (SM City)',
  '694': 'Pagadian (C3 Mall)',
  '27': 'Pampanga (Robinsons StarMills)',
  '553': 'Paniqui, Tarlac (WalterMart)',
  '26': 'Puerto Princesa (Robinsons)',
  '425': 'Santiago, Isabela (Robinsons)',
  '28': 'Tacloban (Robinsons)',
  '709': 'Tagbilaran (Alturas Mall)',
  '491': 'Tagum (Robinsons)',
  '29': 'Tuguegarao (Reg. Govt Center)',
  '30': 'Zamboanga (Go-Velayo Bldg)',
};

class AgencyRepository {
  static final _client = Supabase.instance.client;

  static Future<List<Agency>> fetchAgencies() async {
    // Fetch agencies and slots in parallel for speed
    final results = await Future.wait([
      _client.from('agencies').select(),
      // Order by date so display is always chronological.
      // limit(2000) future-proofs against Supabase's default 1000-row cap.
      _client
          .from('slots')
          .select('agency_id, site_id, slot_date')
          .order('slot_date', ascending: true)
          .limit(2000),
    ]);

    final agenciesData = results[0] as List<dynamic>;
    final slotsData = results[1] as List<dynamic>;

    debugPrint('Fetched ${agenciesData.length} agencies');
    debugPrint('Fetched ${slotsData.length} slots');

    // Pre-group slots by agency_id — avoids scanning full list per agency
    final slotsByAgency = <String, List<Map<String, dynamic>>>{};
    for (final s in slotsData) {
      final agencyId = s['agency_id'] as String;
      slotsByAgency.putIfAbsent(agencyId, () => []).add(s as Map<String, dynamic>);
    }

    return agenciesData.map((row) {
      final agencyId = row['id'] as String;
      final agencySlots = slotsByAgency[agencyId] ?? [];

      // Dates already ordered ascending from the query
      final allDates = agencySlots
          .map((s) => DateTime.parse(s['slot_date'] as String))
          .toList();

      List<DfaSite> sites = [];
      if (agencyId == 'dfa') {
        // Group slots by site_id
        final slotsBySite = <String, List<DateTime>>{};
        for (final s in agencySlots) {
          final siteId = s['site_id'] as String?;
          if (siteId == null) continue;
          slotsBySite
              .putIfAbsent(siteId, () => [])
              .add(DateTime.parse(s['slot_date'] as String));
        }

        // Build a DfaSite for EVERY known location — even those with no slots
        // yet — so the dropdown always shows all 41 locations, not just the
        // ones that happen to have data today.
        sites = _dfaSiteNames.entries.map((entry) {
          return DfaSite(
            id: entry.key,
            name: entry.value,
            availableDates: slotsBySite[entry.key] ?? [],
          );
        }).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }

      return Agency(
        id: agencyId,
        name: row['name'],
        description: row['description'] ?? '',
        websiteUrl: row['website_url'],
        icon: _iconFromName(row['icon_name']),
        availableDates: allDates,
        sites: sites,
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