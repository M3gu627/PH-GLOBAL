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
    final agenciesData = await _client.from('agencies').select();
    final slotsData = await _client.from('slots').select();

    debugPrint('Fetched ${agenciesData.length} agencies');
    debugPrint('Fetched ${slotsData.length} slots');

    return agenciesData.map((row) {
      final agencySlots = slotsData
          .where((s) => s['agency_id'] == row['id'])
          .toList();

      final allDates = agencySlots
          .map((s) => DateTime.parse(s['slot_date'] as String))
          .toList();

      List<DfaSite> sites = [];
      if (row['id'] == 'dfa') {
        final siteIds = agencySlots
            .map((s) => s['site_id'] as String?)
            .whereType<String>()
            .toSet();

        sites = siteIds.map((siteId) {
          final siteDates = agencySlots
              .where((s) => s['site_id'] == siteId)
              .map((s) => DateTime.parse(s['slot_date'] as String))
              .toList();
          return DfaSite(
            id: siteId,
            name: _dfaSiteNames[siteId] ?? 'DFA Site $siteId',
            availableDates: siteDates,
          );
        }).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }

      return Agency(
        id: row['id'],
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