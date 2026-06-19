import 'package:flutter/material.dart';
import '../models/agency.dart';

final mockAgencies = [
  Agency(
    id: 'dfa',
    name: 'Department of Foreign Affairs (Passport)',
    description: 'Department of Foreign Affairs',
    websiteUrl: 'https://www.passport.gov.ph',
    icon: Icons.flight_takeoff,
    availableDates: [DateTime(2026, 9, 9), DateTime(2026, 9, 13)],
  ),
  Agency(
    id: 'nbi',
    name: 'NBI Clearance',
    description: 'National Bureau of Investigation',
    websiteUrl: 'https://clearance.nbi.gov.ph',
    icon: Icons.fingerprint,
    availableDates: [],
  ),
  Agency(
    id: 'philhealth',
    name: 'PhilHealth',
    description: 'Philippine Health Insurance Corporation',
    websiteUrl: 'https://www.philhealth.gov.ph',
    icon: Icons.local_hospital,
    availableDates: [DateTime(2026, 6, 20)],
  ),
];