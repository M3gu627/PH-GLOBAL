import 'package:flutter/material.dart';

class DfaSite {
  final String id;
  final String name;
  final List<DateTime> availableDates;

  const DfaSite({
    required this.id,
    required this.name,
    required this.availableDates,
  });
}

class Agency {
  final String id;
  final String name;
  final String description;
  final String websiteUrl;
  final IconData icon;
  final List<DateTime> availableDates;
  final List<DfaSite> sites;

  const Agency({
    required this.id,
    required this.name,
    required this.description,
    required this.websiteUrl,
    required this.icon,
    required this.availableDates,
    this.sites = const [],
  });

  bool get hasSlots => availableDates.isNotEmpty;
}