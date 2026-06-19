import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/agency.dart';
import '../services/notification_service.dart';
import '../services/fcm_service.dart';
import '../widgets/month_calendar.dart';

class AgencyDetailScreen extends StatefulWidget {
  final Agency agency;
  final List<Agency> allAgencies;
  const AgencyDetailScreen({super.key, required this.agency, required this.allAgencies});

  @override
  State<AgencyDetailScreen> createState() => _AgencyDetailScreenState();
}

class _AgencyDetailScreenState extends State<AgencyDetailScreen> {
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  Future<void> _openWebsite() async {
    final uri = Uri.parse(widget.agency.websiteUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open website')));
    }
  }

  Future<void> _toggleNotify() async {
    final wasNotified = NotificationService.instance.isNotified(widget.agency.id);
    NotificationService.instance.toggle(widget.agency.id);

    if (!wasNotified) {
      await FcmService.subscribeToAgency(widget.agency.id);
    } else {
      await FcmService.unsubscribeFromAgency(widget.agency.id);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(!wasNotified ? 'You\'ll be notified when a slot opens' : 'Notifications turned off')),
    );
  }

  void _goToAgency(int delta) {
    final index = widget.allAgencies.indexWhere((a) => a.id == widget.agency.id);
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= widget.allAgencies.length) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AgencyDetailScreen(agency: widget.allAgencies[newIndex], allAgencies: widget.allAgencies),
      ),
    );
  }

  String _formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

  @override
  Widget build(BuildContext context) {
    final agency = widget.agency;
    final index = widget.allAgencies.indexWhere((a) => a.id == agency.id);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.menu), onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: NotificationService.instance.notifiedAgencyIds,
                    builder: (context, notifiedIds, _) {
                      final isNotified = notifiedIds.contains(agency.id);
                      return ElevatedButton.icon(
                        onPressed: _toggleNotify,
                        icon: Icon(isNotified ? Icons.notifications_active : Icons.notifications_none),
                        label: Text(isNotified ? 'NOTIFYING' : 'NOTIFY ME'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isNotified ? const Color(0xFF8B5CF6) : Colors.black,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _openWebsite,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(child: Text(agency.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))),
                      const Icon(Icons.open_in_new, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              MonthCalendar(highlightedDates: agency.availableDates),
              const SizedBox(height: 16),
              if (agency.hasSlots) ...[
                const Text('AVAILABLE DATES:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...agency.availableDates.map((d) => Text(_formatDate(d), style: const TextStyle(fontWeight: FontWeight.bold))),
              ] else
                const Text('No slots open right now.', style: TextStyle(color: Colors.grey)),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, size: 32), onPressed: index > 0 ? () => _goToAgency(-1) : null),
                  IconButton(icon: const Icon(Icons.arrow_forward, size: 32), onPressed: index < widget.allAgencies.length - 1 ? () => _goToAgency(1) : null),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}