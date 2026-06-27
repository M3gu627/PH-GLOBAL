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

const _birSiteNames = {
  'RegularLargeTaxpayerAuditDivisionIeAppointment@bir.gov.ph': 'Regular Large Taxpayer Audit Division I',
  'RegularLargeTaxpayerAuditDivisionIIeAppointment@bir.gov.ph': 'Regular Large Taxpayer Audit Division II',
  'RegularLargeTaxpayerAuditDivisionIIIeAppointment@bir.gov.ph': 'Regular Large Taxpayer Audit Division III',
  'ExcisteLargeTaxpayerAuditDivisionI@bir.gov.ph': 'Excise Large Taxpayer Audit Division I',
  'ExciseLargeTaxpayerAuditDivisionII@bir.gov.ph': 'Excise Large Taxpayer Audit Division II',
  'ExciseLargeTaxpayersFieldOperationsDivisioneAppointment@bir.gov.ph': 'Excise LT Field Operations Division',
  'ExciseLargeTaxpayerRegulatoryDivision@bir.gov.ph': 'Excise Large Taxpayer Regulatory Division (ELTRD)',
  'LargeTaxpayerAssistanceDivisioneAppointmentPortalPage@bir.gov.ph': 'Large Taxpayer Assistance Division (LTAD)',
  'LargeTaxpayerDivisionOfficeCebu@bir.gov.ph': 'Large Taxpayer Division Cebu',
  'RDO127LargeTaxDivisionDavaoeAppointmentPortal@bir.gov.ph': 'Large Taxpayer Division Davao',
  'RDO001AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 1 – Laoag City',
  'RDO002AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 2 – Vigan',
  'RDO001AssessmentSectionASeAppointmentPortal1@bir.gov.ph': 'RDO No. 3 – San Fernando, La Union',
  'RDO04AssessmenteAppointmentPortal@bir.gov.ph': 'RDO No. 4 – Calasiao, West Pangasinan',
  'RDO05AssessmenteAppointmentPortal@bir.gov.ph': 'RDO No. 5 – Alaminos, West Pangasinan',
  'RDO006AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 6 – Urdaneta City',
  'RDO007AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 7 – Bangued, Abra',
  'RDO008AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 8 – Baguio City',
  'RDO009AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 9 – La Trinidad, Benguet',
  'RDO010AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 10 – Bontoc, Mountain Province',
  'RDO011AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 11 – Tabuk City, Kalinga',
  'RDO012AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 12 – Lagawe, Ifugao',
  'RDO013AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 13 – Tuguegarao City',
  'RDO014AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 14 – Bayombong, Nueva Vizcaya',
  'RDO15AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 15 – Naguilian, Isabela',
  'RDO016AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 16 – Cabarroguis, Quirino',
  'RDO17AAssessmentServiceASeAppointmentPortal1@bir.gov.ph': 'RDO No. 17A – Tarlac City',
  'RDO17BAssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 17B – Paniqui, Tarlac',
  'RDO018AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 18 – Olongapo City',
  'RDO019AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 19 – Subic Bay Freeport Zone',
  'RDO020AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 20 – Balanga, Bataan',
  'RDO21AAssessmentServiceASeAppoinmentPortal@bir.gov.ph': 'RDO No. 21A – North Pampanga',
  'RDO21BAssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 21B – South Pampanga',
  'RDO21CAssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 21C – Clark Freeport Zone',
  'RDO022AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 22 – Baler, Aurora',
  'RDO23AAssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 23A – North Nueva Ecija',
  'RDO23BAssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 23B – South Nueva Ecija',
  'RDO024AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 24 – Valenzuela City',
  'RDO25AAssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 25A – West Bulacan',
  'RDO25BAssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 25B – East Bulacan',
  'RDO026AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 26 – Malabon/Navotas',
  'RDO027AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 27 – Caloocan City',
  'RDO028AssessmentServiceASeAppointmentPortal1@bir.gov.ph': 'RDO No. 28 – Novaliches',
  'RDO029AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 29 – San Nicolas, Tondo',
  'RDO030AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 30 – Binondo',
  'RDO031AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 31 – Sta. Cruz',
  'RDO032AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 32 – Quiapo/Sampaloc',
  'RDO033AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 33 – Intramuros/Ermita',
  'RDO034AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 34 – Paco/Pandacan',
  'RDO035AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 35 – Odiongan, Romblon',
  'RDO036AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 36 – Puerto Princesa',
  'RDO037AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 37 – San Jose, Occ. Mindoro',
  'RDO38NorthQuezonCityeAppointment@bir.gov.ph': 'RDO No. 38 – North Quezon City',
  'RDO039AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 39 – South Quezon City',
  'RDO040AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 40 – Cubao',
  'RDO041AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 41 – Mandaluyong',
  'RDO042AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 42 – San Juan',
  'RDO043AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 43 – Pasig City',
  'RDO044AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 44 – Taguig/Pateros',
  'RDO045AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 45 – Marikina',
  'RDO046AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 46 – Cainta/Taytay',
  'RDO047AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 47 – East Makati',
  'RDO048AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 48 – West Makati',
  'RDO049AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 49 – North Makati',
  'RDO050AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 50 – South Makati',
  'RDO051AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 51 – Pasay City',
  'RDO052CollectionSectionCSeAppointmentPortalCopy@bir.gov.ph': 'RDO No. 52 – Paranaque',
  'RDO53AAssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 53A – Las Piñas',
  'RDO53BAssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 53B – Muntinlupa',
  'RDO54AAssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 54A – East Cavite',
  'RDO54BAssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 54B – West Cavite',
  'RDO055AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 55 – San Pablo City',
  'RDO056AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 56 – Calamba, Laguna',
  'RDO057AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 57 – West Laguna',
  'RDO058AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 58 – Batangas City',
  'RDO059AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 59 – Lipa City',
  'RDO060AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 60 – Lucena City',
  'RDO061AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 61 – Gumaca, South Quezon',
  'RDO062AssessmentServiceASeAppointmentPortal1@bir.gov.ph': 'RDO No. 62 – Boac, Marinduque',
  'RDO063AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 63 – Calapan, Oriental Mindoro',
  'RDO064AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 64 – Talisay, Camarines Norte',
  'RDO065AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 65 – Naga City',
  'RDO066AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 66 – Iriga City',
  'RDO067AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 67 – Legazpi City',
  'RDO068AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 68 – Sorsogon',
  'RDO069AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 69 – Virac, Catanduanes',
  'RDO070AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 70 – Masbate City',
  'RDO071AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 71 – Kalibo, Aklan',
  'RDO072AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 72 – Roxas City, Capiz',
  'RDO073AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 73 – San Jose, Antique',
  'RDO074AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 74 – Iloilo City',
  'RDO075AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 75 – Zarraga, Iloilo',
  'RDO076AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 76 – Victorias, Negros Occ.',
  'RDO077AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 77 – Bacolod City',
  'RDO078AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 78 – Binalbagan, Negros Occ.',
  'RDO079AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 79 – Dumaguete City',
  'RDO080AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 80 – Mandaue City',
  'RDO081AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 81 – Cebu City North',
  'RDO082AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 82 – Cebu City South',
  'RDO83AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 83 – Talisay, Cebu',
  'RDO84TagbilaranCityBoholeAppointment@bir.gov.ph': 'RDO No. 84 – Tagbilaran City',
  'RDO085AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 85 – Catarman, Northern Samar',
  'RDO086AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 86 – Borongan, Eastern Samar',
  'RDO087AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 87 – Calbayog City, Samar',
  'RDO088AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 88 – Tacloban City',
  'RDO089AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 89 – Ormoc City',
  'RDO090AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 90 – Maasin, Southern Leyte',
  'RDO091AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 91 – Dipolog City',
  'RDO092AssessmentServiceCSeAppointmentPortal1@bir.gov.ph': 'RDO No. 92 – Pagadian City',
  'RDO93AAssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 93A – Zamboanga City',
  'RDO93BAssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 93B – Ipil, Zamboanga Sibugay',
  'RDO094AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 94 – Isabela City, Basilan',
  'RDO095AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 95 – Jolo, Sulu',
  'RDO096AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 96 – Bongao, Tawi-Tawi',
  'RDO097AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 97 – Gingoog City',
  'RDO098AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 98 – Cagayan de Oro City',
  'RDO099AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 99 – Malaybalay, Bukidnon',
  'RDO100AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 100 – Ozamis City',
  'RDO101AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 101 – Iligan City',
  'RDO102AssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 102 – Marawi City',
  'RDO103AssessmentSectionASeAppointmentPortal1@bir.gov.ph': 'RDO No. 103 – Butuan City',
  'RDO104AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 104 – Bayugan City',
  'RDO105AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 105 – Surigao City',
  'RDO106AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 106 – Tandag City',
  'RDO107AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 107 – Cotabato City',
  'RDO108AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 108 – Kidapawan City',
  'RDO109AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 109 – Tacurong, Sultan Kudarat',
  'RDO110AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 110 – General Santos City',
  'RDO111AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 111 – Koronadal City',
  'RDO112AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 112 – Tagum City',
  'RDO113AAssessmentServiceASeAppointmentPortal@bir.gov.ph': 'RDO No. 113A – West Davao City',
  'RDO113BAssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 113B – East Davao City',
  'RDO114AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 114 – Mati City, Davao Oriental',
  'RDO115AssessmentSectionASeAppointmentPortal@bir.gov.ph': 'RDO No. 115 – Digos City, Davao del Sur',
};

// PSA outlet names keyed by outlet_id (matches psa_outlet_ids.json)
const _psaSiteNames = {
  '4':  'North Caloocan',
  '5':  'Muntinlupa',
  '6':  'Paranaque',
  '7':  'Valenzuela',
  '24': 'Cotabato City',
  '73': 'Bongao Tawi-Tawi',
  '79': 'Marawi City',
  '35': 'Baguio City',
  '36': 'Abra',
  '53': 'Tabuk City Kalinga',
  '81': 'Mobile UP Baguio',
  '86': 'Luna Apayao',
  '21': 'Butuan City',
  '46': 'Surigao City',
  '72': 'Tandag City',
  '78': 'San Francisco',
  '8':  'San Fernando La Union',
  '9':  'Calasiao Pangasinan',
  '25': 'Vigan',
  '37': 'Ilocos Norte',
  '65': 'Rosales Pangasinan',
  '85': 'Candon Ilocos Sur',
  '10': 'Bayombong Nueva Vizcaya',
  '41': 'Tuguegarao City',
  '55': 'Quirino',
  '61': 'Isabela',
  '11': 'San Fernando Pampanga',
  '12': 'Cabanatuan City',
  '26': 'Olongapo',
  '50': 'Tarlac City',
  '51': 'Aurora',
  '58': 'Bulacan',
  '13': 'Lipa City Batangas',
  '14': 'Lucena City Quezon',
  '49': 'Cavite',
  '52': 'Antipolo Rizal',
  '66': 'San Pablo',
  '28': 'Calapan',
  '62': 'Mamburao',
  '63': 'Odiongan',
  '84': 'Boac Marinduque',
  '38': 'Puerto Princesa',
  '15': 'Legaspi City Albay',
  '42': 'Naga City',
  '48': 'Masbate',
  '54': 'Virac',
  '71': 'Sorsogon City',
  '76': 'Daet',
  '16': 'Iloilo City',
  '32': 'Kalibo',
  '56': 'Antique',
  '59': 'Capiz',
  '34': 'Cebu',
  '45': 'Tagbilaran',
  '17': 'Tacloban City Leyte',
  '23': 'Catbalogan',
  '68': 'Catarman',
  '67': 'Borongan',
  '70': 'Maasin City',
  '75': 'Naval Biliran',
  '22': 'Zamboanga City',
  '40': 'Dipolog City',
  '44': 'Pagadian City',
  '80': 'Ipil',
  '87': 'Sulu',
  '18': 'Cagayan De Oro City',
  '27': 'Malaybalay City',
  '30': 'Iligan City',
  '33': 'Ozamiz',
  '83': 'Mambajao Camiguin',
  '19': 'Davao City',
  '43': 'Tagum',
  '64': 'Digos',
  '74': 'Mati City',
  '77': 'Malita Davao Occidental',
  '82': 'Nabunturan Davao De Oro',
  '20': 'General Santos City',
  '57': 'Kidapawan City',
  '69': 'Tacurong City',
  '47': 'Koronadal',
  '31': 'Bacolod City',
  '39': 'Dumaguete City',
};

class AgencyRepository {
  static final _client = Supabase.instance.client;

  // ── Fetch all agencies (used on app startup) ──────────────────────────────

  static Future<List<Agency>> fetchAgencies() async {
    final results = await Future.wait([
      _client.from('agencies').select(),
      _client
          .from('slots')
          .select('agency_id, site_id, slot_date')
          .order('slot_date', ascending: true)
          .limit(5000),
    ]);

    final agenciesData = results[0] as List<dynamic>;
    final slotsData = results[1] as List<dynamic>;

    debugPrint('Fetched ${agenciesData.length} agencies');
    debugPrint('Fetched ${slotsData.length} slots');

    final slotsByAgency = <String, List<Map<String, dynamic>>>{};
    for (final s in slotsData) {
      final agencyId = s['agency_id'] as String;
      slotsByAgency.putIfAbsent(agencyId, () => []).add(s as Map<String, dynamic>);
    }

    return agenciesData.map((row) {
      final agencyId = row['id'] as String;
      final agencySlots = slotsByAgency[agencyId] ?? [];
      return _buildAgency(row, agencySlots);
    }).toList();
  }

  // ── Refresh a single agency ───────────────────────────────────────────────

  static Future<Agency> refreshAgency(String agencyId) async {
    final results = await Future.wait([
      _client.from('agencies').select().eq('id', agencyId).single(),
      _client
          .from('slots')
          .select('agency_id, site_id, slot_date')
          .eq('agency_id', agencyId)
          .order('slot_date', ascending: true),
    ]);

    final agencyData = results[0] as Map<String, dynamic>;
    final slotsData = (results[1] as List<dynamic>).cast<Map<String, dynamic>>();

    debugPrint('Refreshed $agencyId — ${slotsData.length} slots');

    return _buildAgency(agencyData, slotsData);
  }

  // ── Shared builder ────────────────────────────────────────────────────────

  static Agency _buildAgency(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> agencySlots,
  ) {
    final agencyId = row['id'] as String;

    final allDates = agencySlots
        .map((s) => DateTime.parse(s['slot_date'] as String))
        .toList();

    List<DfaSite> sites = [];
    if (agencyId == 'dfa') {
      sites = _buildSites(agencySlots, _dfaSiteNames);
    } else if (agencyId == 'bir') {
      sites = _buildSites(agencySlots, _birSiteNames);
    } else if (agencyId == 'psa') {
      // PSA site_id format: "psa_4", "psa_5" etc.
      // Strip "psa_" prefix to match _psaSiteNames keys
      sites = _buildSites(agencySlots, _psaSiteNames);
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
  }

  // ── Site-building logic ───────────────────────────────────────────────────

  static List<DfaSite> _buildSites(
    List<Map<String, dynamic>> agencySlots,
    Map<String, String> siteNames,
  ) {
    final slotsBySite = <String, List<DateTime>>{};
    for (final s in agencySlots) {
      final rawSiteId = s['site_id'] as String?;
      if (rawSiteId == null) continue;
      // Strip agency prefix: "dfa_489" → "489", "psa_4" → "4"
      final siteKey = rawSiteId.contains('_')
          ? rawSiteId.substring(rawSiteId.indexOf('_') + 1)
          : rawSiteId;
      slotsBySite
          .putIfAbsent(siteKey, () => [])
          .add(DateTime.parse(s['slot_date'] as String));
    }

    return siteNames.entries.map((entry) {
      return DfaSite(
        id: 'psa_${entry.key}', // keep full site_id for PSA notify key
        name: entry.value,
        availableDates: slotsBySite[entry.key] ?? [],
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  static IconData _iconFromName(String? name) {
    switch (name) {
      case 'flight_takeoff': return Icons.flight_takeoff;
      case 'fingerprint':    return Icons.fingerprint;
      case 'local_hospital': return Icons.local_hospital;
      case 'account_balance':return Icons.account_balance;
      default:               return Icons.business;
    }
  }
}