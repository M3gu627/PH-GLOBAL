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
  DfaSite? _selectedSite;

  @override
  void initState() {
    super.initState();
    if (widget.agency.sites.isNotEmpty) {
      _selectedSite = widget.agency.sites.first;
    }
  }

  List<DateTime> get _displayDates =>
      _selectedSite?.availableDates ?? widget.agency.availableDates;

  bool get _isDfa => widget.agency.id == 'dfa';

  String get _notifyKey => _isDfa && _selectedSite != null
      ? '${widget.agency.id}_${_selectedSite!.id}'
      : widget.agency.id;

  Future<void> _openWebsite() async {
    final uri = Uri.parse(widget.agency.websiteUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open website')));
    }
  }

  Future<void> _toggleNotify() async {
    final wasNotified = NotificationService.instance.isNotified(_notifyKey);
    NotificationService.instance.toggle(_notifyKey);

    if (!wasNotified) {
      await FcmService.subscribeToAgency(widget.agency.id, siteId: _selectedSite?.id);
    } else {
      await FcmService.unsubscribeFromAgency(widget.agency.id, siteId: _selectedSite?.id);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(!wasNotified
          ? 'You\'ll be notified when a slot opens'
          : 'Notifications turned off')),
    );
  }

  void _goToAgency(int delta) {
    final index = widget.allAgencies.indexWhere((a) => a.id == widget.agency.id);
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= widget.allAgencies.length) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AgencyDetailScreen(
          agency: widget.allAgencies[newIndex],
          allAgencies: widget.allAgencies,
        ),
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
        child: Column(
          children: [
            // Fixed top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: NotificationService.instance.notifiedAgencyIds,
                    builder: (context, notifiedIds, _) {
                      final isNotified = notifiedIds.contains(_notifyKey);
                      return ElevatedButton.icon(
                        onPressed: _toggleNotify,
                        icon: Icon(isNotified
                            ? Icons.notifications_active
                            : Icons.notifications_none),
                        label: Text(isNotified ? 'NOTIFYING' : 'NOTIFY ME'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isNotified
                              ? const Color(0xFF8B5CF6)
                              : Colors.black,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: _openWebsite,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                agency.name.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.open_in_new, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Location dropdown ──────────────────────────────────
                    // isExpanded: true prevents text overflow on the selected
                    // item. selectedItemBuilder renders a clipped single-line
                    // version in the closed button; the full name is still
                    // visible in the open menu list.
                    if (_isDfa && agency.sites.isNotEmpty)
                      DropdownButtonFormField<DfaSite>(
                        value: _selectedSite,
                        isExpanded: true,
                        dropdownColor: Colors.black,
                        decoration: InputDecoration(
                          labelText: 'Select Location',
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        // Closed state: single line, ellipsis if too long
                        selectedItemBuilder: (context) =>
                            agency.sites.map((site) {
                          return Text(
                            site.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(color: Colors.white),
                          );
                        }).toList(),
                        // Open menu: each item also clips, keeps menu tidy
                        items: agency.sites.map((site) {
                          return DropdownMenuItem(
                            value: site,
                            child: Text(
                              site.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (site) =>
                            setState(() => _selectedSite = site),
                      ),

                    const SizedBox(height: 16),
                    MonthCalendar(highlightedDates: _displayDates),
                    const SizedBox(height: 16),
                    if (_displayDates.isNotEmpty) ...[
                      const Text('AVAILABLE DATES:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._displayDates.map((d) => Text(_formatDate(d),
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                    ] else
                      const Text('No slots open right now.',
                          style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Fixed bottom nav
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 32),
                    onPressed: index > 0 ? () => _goToAgency(-1) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 32),
                    onPressed: index < widget.allAgencies.length - 1
                        ? () => _goToAgency(1)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}