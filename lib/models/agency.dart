import 'package:flutter/material.dart';

class Agency {
  final String id;
  final String name;
  final String description;
  final String websiteUrl;
  final IconData icon;
  final List<DateTime> availableDates;

  const Agency({
    required this.id,
    required this.name,
    required this.description,
    required this.websiteUrl,
    required this.icon,
    required this.availableDates,
  });

  bool get hasSlots => availableDates.isNotEmpty;
}