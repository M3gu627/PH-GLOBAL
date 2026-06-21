import 'package:flutter/material.dart';
import '../models/agency.dart';
import '../services/agency_repository.dart';
import '../services/notification_service.dart';
import '../services/fcm_service.dart';
import 'agency_detail_screen.dart';

const _purple = Color(0xFF8B5CF6);
const _background = Color(0xFF0F0F0F);

// DFA site name lookup — same as agency_repository.dart
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

// Parses a notifyKey like "dfa_489" into a human-readable label
String _labelFromKey(String key) {
  final parts = key.split('_');
  if (parts.length == 1) {
    // Non-DFA agency key e.g. "nbi"
    return parts[0].toUpperCase();
  }
  final agency = parts[0].toUpperCase(); // "DFA"
  final siteId = parts.sublist(1).join('_'); // "489"
  final siteName = _dfaSiteNames[siteId];
  if (siteName != null) return '$agency — $siteName';
  return '$agency — Site $siteId';
}

// Parses agency_id and site_id back out of a notifyKey
(String agencyId, String? siteId) _parseKey(String key) {
  final parts = key.split('_');
  if (parts.length == 1) return (parts[0], null);
  return (parts[0], parts.sublist(1).join('_'));
}

class AgencyListScreen extends StatefulWidget {
  const AgencyListScreen({super.key});

  @override
  State<AgencyListScreen> createState() => _AgencyListScreenState();
}

class _AgencyListScreenState extends State<AgencyListScreen> {
  late Future<List<Agency>> _agenciesFuture;

  @override
  void initState() {
    super.initState();
    _agenciesFuture = AgencyRepository.fetchAgencies();
  }

  Future<void> _refresh() async {
    setState(() => _agenciesFuture = AgencyRepository.fetchAgencies());
    await _agenciesFuture;
  }

  void _openAgency(Agency agency, List<Agency> all) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgencyDetailScreen(agency: agency, allAgencies: all),
      ),
    );
  }

  // Shows a bottom sheet listing all active notification subscriptions
  void _showNotificationsSheet(Set<String> notifiedKeys) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => _NotificationsSheet(notifiedKeys: notifiedKeys),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text('PH NOTIFY'),
        actions: [
          ValueListenableBuilder<Set<String>>(
            valueListenable: NotificationService.instance.notifiedAgencyIds,
            builder: (context, notified, _) => IconButton(
              icon: Badge(
                isLabelVisible: notified.isNotEmpty,
                label: Text('${notified.length}'),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () => _showNotificationsSheet(notified),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Agency>>(
        future: _agenciesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _purple),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
                error: snapshot.error.toString(), onRetry: _refresh);
          }

          final agencies = snapshot.data ?? [];
          if (agencies.isEmpty) {
            return const Center(
              child: Text('No agencies available yet.',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          return RefreshIndicator(
            color: _purple,
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: agencies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final agency = agencies[index];
                return _AgencyCard(
                  agency: agency,
                  onTap: () => _openAgency(agency, agencies),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications bottom sheet
// ---------------------------------------------------------------------------

class _NotificationsSheet extends StatefulWidget {
  final Set<String> notifiedKeys;
  const _NotificationsSheet({required this.notifiedKeys});

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  // Local copy so we can update UI immediately on unsubscribe
  late Set<String> _keys;

  @override
  void initState() {
    super.initState();
    _keys = Set.from(widget.notifiedKeys);
  }

  Future<void> _unsubscribe(String key) async {
    final (agencyId, siteId) = _parseKey(key);

    // Update local state immediately for snappy UI
    setState(() => _keys.remove(key));

    // Update global notification service
    NotificationService.instance.toggle(key);

    // Remove from Supabase
    await FcmService.unsubscribeFromAgency(agencyId, siteId: siteId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unsubscribed from ${_labelFromKey(key)}'),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: _purple),
                  const SizedBox(width: 10),
                  const Text(
                    'MY NOTIFICATIONS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  if (_keys.isNotEmpty)
                    Text(
                      '${_keys.length} active',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: Color(0xFF2A2A2A)),

            // List or empty state
            Expanded(
              child: _keys.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              color: Colors.grey, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'No active notifications',
                            style: TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Tap "Notify Me" on a location to get started',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _keys.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Color(0xFF2A2A2A)),
                      itemBuilder: (context, index) {
                        final key = _keys.elementAt(index);
                        final label = _labelFromKey(key);
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF2A1F3D),
                            child: Icon(Icons.notifications_active,
                                color: _purple, size: 20),
                          ),
                          title: Text(
                            label,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          subtitle: const Text(
                            'Notifying when slots open',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          trailing: TextButton.icon(
                            onPressed: () => _unsubscribe(key),
                            icon: const Icon(Icons.notifications_off,
                                size: 16, color: Colors.redAccent),
                            label: const Text(
                              'Remove',
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 13),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Agency card
// ---------------------------------------------------------------------------

class _AgencyCard extends StatelessWidget {
  final Agency agency;
  final VoidCallback onTap;
  const _AgencyCard({required this.agency, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _purple.withValues(alpha: 0.2),
                child: Icon(agency.icon, color: _purple),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agency.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      agency.hasSlots
                          ? '${agency.availableDates.length} slot(s) open'
                          : 'No slots open',
                      style: TextStyle(
                        color: agency.hasSlots ? _purple : Colors.grey,
                        fontWeight: agency.hasSlots
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}