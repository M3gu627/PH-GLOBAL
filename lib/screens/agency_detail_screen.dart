import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/agency.dart';
import '../services/agency_repository.dart';
import '../services/fcm_service.dart';
import '../services/notification_service.dart';
import '../widgets/month_calendar.dart';

// ── PSA data ──────────────────────────────────────────────────────────────────

const _psaRegions = [
  'NCR', 'BARMM', 'CAR', 'CARAGA',
  'REGION I', 'REGION II', 'REGION III', 'REGION IV-A',
  'MIMAROPA', 'REGION V', 'REGION VI', 'REGION VII',
  'REGION VIII', 'REGION IX', 'REGION X', 'REGION XI',
  'REGION XII', 'Negros Island Region',
];

const _psaOutletIdsByRegion = <String, List<String>>{
  'NCR':                  ['4', '5', '6', '7'],
  'BARMM':                ['24', '73', '79'],
  'CAR':                  ['35', '36', '53', '81', '86'],
  'CARAGA':               ['21', '46', '72', '78'],
  'REGION I':             ['8', '9', '25', '37', '65', '85'],
  'REGION II':            ['10', '41', '55', '61'],
  'REGION III':           ['11', '12', '26', '50', '51', '58'],
  'REGION IV-A':          ['13', '14', '49', '52', '66'],
  'MIMAROPA':             ['28', '38', '62', '63', '84'],
  'REGION V':             ['15', '42', '48', '54', '71', '76'],
  'REGION VI':            ['16', '32', '56', '59'],
  'REGION VII':           ['34', '45'],
  'REGION VIII':          ['17', '23', '67', '68', '70', '75'],
  'REGION IX':            ['22', '40', '44', '80', '87'],
  'REGION X':             ['18', '27', '30', '33', '83'],
  'REGION XI':            ['19', '43', '64', '74', '77', '82'],
  'REGION XII':           ['20', '47', '57', '69'],
  'Negros Island Region': ['31', '39'],
};

const _psaPurposes = [
  'Birth Certificate',
  'Marriage Certificate',
  'Death Certificate',
  'Certificate of No Marriage (CENOMAR)',
];

// ── Screen ────────────────────────────────────────────────────────────────────

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

  late Agency _agency;
  DfaSite? _selectedSite;
  bool _isRefreshing = false;

  // PSA-specific
  String? _psaRegion;
  String? _psaPurpose;
  DfaSite? _psaOutlet;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _agency = widget.agency;
    if (_agency.sites.isNotEmpty && !_isPsa) {
      _selectedSite = _agency.sites.first;
    }
    FcmService.registerRefreshCallback(_agency.id, _onFcmRefresh);

    // Auto-refresh on open so data is always current
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  @override
  void dispose() {
    FcmService.unregisterRefreshCallback(_agency.id, _onFcmRefresh);
    super.dispose();
  }

  // ── Refresh ───────────────────────────────────────────────────────────────

  void _onFcmRefresh() => _refreshData();

  Future<void> _refreshData() async {
    if (_isRefreshing || !mounted) return;
    setState(() => _isRefreshing = true);
    try {
      final updated = await AgencyRepository.refreshAgency(_agency.id);
      if (!mounted) return;
      setState(() {
        _agency = updated;
        if (_isPsa) {
          if (_psaOutlet != null) {
            _psaOutlet = updated.sites
                .where((s) => s.id == _psaOutlet!.id)
                .firstOrNull;
          }
        } else {
          if (_selectedSite != null) {
            _selectedSite = updated.sites
                .where((s) => s.id == _selectedSite!.id)
                .firstOrNull;
          }
          _selectedSite ??=
              updated.sites.isNotEmpty ? updated.sites.first : null;
        }
        _isRefreshing = false;
      });
    } catch (e) {
      debugPrint('Refresh failed: $e');
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get _isPsa => _agency.id == 'psa';

  List<DateTime> get _displayDates {
    if (_isPsa) return _psaOutlet?.availableDates ?? [];
    return _selectedSite?.availableDates ?? _agency.availableDates;
  }

  bool get _hasSites => _agency.sites.isNotEmpty;

  String get _notifyKey {
    if (_isPsa && _psaOutlet != null) {
      // _psaOutlet.id is already 'psa_4' — use it directly
      return _psaOutlet!.id;
    }
    return _hasSites && _selectedSite != null
        ? '${_agency.id}_${_selectedSite!.id}'
        : _agency.id;
  }

  String get _dropdownLabel =>
      _agency.id == 'bir' ? 'Select RDO' : 'Select Location';

  List<DfaSite> get _psaRegionOutlets {
    if (_psaRegion == null) return [];
    final ids = _psaOutletIdsByRegion[_psaRegion!] ?? [];
    return ids
        .map((id) => _agency.sites
            .where((s) => s.id == 'psa_$id')
            .firstOrNull)
        .whereType<DfaSite>()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

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
      siteId: _isPsa ? _psaOutlet?.id : _selectedSite?.id,
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
    final index = widget.allAgencies.indexWhere((a) => a.id == _agency.id);
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
    final index = widget.allAgencies.indexWhere((a) => a.id == _agency.id);

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
                  if (_isRefreshing)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 20, height: 20,
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

                    // ── PSA: purpose → region → outlet ────────────────────
                    if (_isPsa) ...[
                      _buildDropdown<String>(
                        label: 'Select Purpose',
                        value: _psaPurpose,
                        items: _psaPurposes,
                        itemLabel: (p) => p,
                        onChanged: (p) => setState(() => _psaPurpose = p),
                      ),
                      const SizedBox(height: 12),

                      _buildDropdown<String>(
                        label: 'Select Region',
                        value: _psaRegion,
                        items: _psaRegions,
                        itemLabel: (r) => r,
                        onChanged: (r) => setState(() {
                          _psaRegion = r;
                          _psaOutlet = null;
                        }),
                      ),
                      const SizedBox(height: 12),

                      if (_psaRegion != null)
                        _buildDropdown<DfaSite>(
                          label: 'Select Outlet',
                          value: _psaOutlet,
                          items: _psaRegionOutlets,
                          itemLabel: (s) => s.name,
                          onChanged: (s) => setState(() => _psaOutlet = s),
                        ),
                      const SizedBox(height: 16),
                    ]

                    // ── DFA / BIR: single dropdown ────────────────────────
                    else if (_hasSites) ...[
                      _buildDropdown<DfaSite>(
                        label: _dropdownLabel,
                        value: _selectedSite,
                        items: _agency.sites,
                        itemLabel: (s) => s.name,
                        onChanged: (s) => setState(() => _selectedSite = s),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Calendar ──────────────────────────────────────────
                    MonthCalendar(highlightedDates: _displayDates),
                    const SizedBox(height: 16),

                    // ── Available dates ───────────────────────────────────
                    if (_displayDates.isNotEmpty) ...[
                      const Text(
                        'AVAILABLE DATES:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._displayDates.map(
                        (d) => Text(
                          _formatDate(d),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else
                      Text(
                        _isPsa && _psaOutlet == null
                            ? 'Select a region and outlet to view slots.'
                            : 'No slots open right now.',
                        style: const TextStyle(color: Colors.grey),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Bottom navigation ─────────────────────────────────────────
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

  // ── Reusable dropdown ─────────────────────────────────────────────────────

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      menuMaxHeight: 300,
      dropdownColor: const Color(0xFF1A1A1A),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.black,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      selectedItemBuilder: (context) => items.map((item) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            itemLabel(item),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            itemLabel(item),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}