import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/agency.dart';
import '../services/agency_repository.dart';
import '../services/fcm_service.dart';
import '../services/notification_service.dart';
import '../widgets/month_calendar.dart';

class AgencyDetailScreen extends StatefulWidget {
  final Agency agency;
  final List<Agency> allAgencies;
  const AgencyDetailScreen({
    super.key,
    required this.agency,
    required this.allAgencies,
  });

  @override
  State<AgencyDetailScreen> createState() => _AgencyDetailScreenState();
}

class _AgencyDetailScreenState extends State<AgencyDetailScreen> {
  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  // ── State ─────────────────────────────────────────────────────────────────

  late Agency _agency;          // mutable — gets replaced on refresh
  DfaSite? _selectedSite;
  bool _isRefreshing = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _agency = widget.agency;
    if (_agency.sites.isNotEmpty) {
      _selectedSite = _agency.sites.first;
    }

    // Register with FCM so this screen refreshes when a notification
    // arrives for the agency currently on screen.
    FcmService.registerRefreshCallback(_agency.id, _onFcmRefresh);
  }

  @override
  void dispose() {
    FcmService.unregisterRefreshCallback(_agency.id, _onFcmRefresh);
    super.dispose();
  }

  // ── Refresh ───────────────────────────────────────────────────────────────

  // Called by FcmService when a notification for this agency arrives.
  void _onFcmRefresh() {
    debugPrint('FCM triggered refresh for ${_agency.id}');
    _refreshData();
  }

  // Fetches fresh slot data for this agency from Supabase and rebuilds UI.
  Future<void> _refreshData() async {
    if (_isRefreshing || !mounted) return;
    setState(() => _isRefreshing = true);

    try {
      final updated = await AgencyRepository.refreshAgency(_agency.id);
      if (!mounted) return;

      setState(() {
        _agency = updated;

        // Keep the user's currently selected site if it still exists
        if (_selectedSite != null) {
          _selectedSite = updated.sites
              .where((s) => s.id == _selectedSite!.id)
              .firstOrNull;
        }
        // Fall back to first site if selection was lost
        _selectedSite ??=
            updated.sites.isNotEmpty ? updated.sites.first : null;

        _isRefreshing = false;
      });

      debugPrint('UI refreshed for ${_agency.id}');
    } catch (e) {
      debugPrint('Refresh failed for ${_agency.id}: $e');
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<DateTime> get _displayDates =>
      _selectedSite?.availableDates ?? _agency.availableDates;

  bool get _hasSites => _agency.sites.isNotEmpty;

  String get _notifyKey => _hasSites && _selectedSite != null
      ? '${_agency.id}_${_selectedSite!.id}'
      : _agency.id;

  String get _dropdownLabel =>
      _agency.id == 'bir' ? 'Select RDO' : 'Select Location';

  Future<void> _openWebsite() async {
    final uri = Uri.parse(_agency.websiteUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open website')),
      );
    }
  }

  Future<void> _toggleNotify() async {
    final wasNotified = NotificationService.instance.isNotified(_notifyKey);
    await NotificationService.instance.toggle(
      _agency.id,
      siteId: _selectedSite?.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(!wasNotified
            ? 'You\'ll be notified when a slot opens'
            : 'Notifications turned off'),
      ),
    );
  }

  void _goToAgency(int delta) {
    final index =
        widget.allAgencies.indexWhere((a) => a.id == _agency.id);
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

  String _formatDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final index =
        widget.allAgencies.indexWhere((a) => a.id == _agency.id);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),

                  // Refresh indicator / manual refresh button
                  if (_isRefreshing)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF8B5CF6)),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh slots',
                      onPressed: _refreshData,
                    ),

                  const SizedBox(width: 4),

                  // Notify Me button
                  ValueListenableBuilder<Set<String>>(
                    valueListenable:
                        NotificationService.instance.notifiedAgencyIds,
                    builder: (context, notifiedIds, _) {
                      final isNotified = notifiedIds.contains(_notifyKey);
                      return ElevatedButton.icon(
                        onPressed: _toggleNotify,
                        icon: Icon(isNotified
                            ? Icons.notifications_active
                            : Icons.notifications_none),
                        label:
                            Text(isNotified ? 'NOTIFYING' : 'NOTIFY ME'),
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

            // ── Scrollable content ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Agency name / website link
                    GestureDetector(
                      onTap: _openWebsite,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _agency.name.toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.open_in_new, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Site / RDO dropdown
                    if (_hasSites)
                      DropdownButtonFormField<DfaSite>(
                        initialValue: _selectedSite,
                        isExpanded: true,
                        dropdownColor: Colors.black,
                        decoration: InputDecoration(
                          labelText: _dropdownLabel,
                          labelStyle:
                              const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.grey),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        selectedItemBuilder: (context) =>
                            _agency.sites.map((site) {
                          return Text(
                            site.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style:
                                const TextStyle(color: Colors.white),
                          );
                        }).toList(),
                        items: _agency.sites.map((site) {
                          return DropdownMenuItem(
                            value: site,
                            child: Text(
                              site.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style:
                                  const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (site) =>
                            setState(() => _selectedSite = site),
                      ),

                    const SizedBox(height: 16),

                    // Calendar
                    MonthCalendar(highlightedDates: _displayDates),
                    const SizedBox(height: 16),

                    // Available dates list
                    if (_displayDates.isNotEmpty) ...[
                      const Text(
                        'AVAILABLE DATES:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._displayDates.map(
                        (d) => Text(
                          _formatDate(d),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else
                      const Text(
                        'No slots open right now.',
                        style: TextStyle(color: Colors.grey),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Bottom navigation ─────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 32),
                    onPressed:
                        index > 0 ? () => _goToAgency(-1) : null,
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