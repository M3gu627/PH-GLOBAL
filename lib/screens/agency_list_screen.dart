import 'package:flutter/material.dart';
import '../models/agency.dart';
import '../services/agency_repository.dart'; // adjust path if yours lives elsewhere
import '../services/notification_service.dart';
import 'agency_detail_screen.dart';

const _purple = Color(0xFF8B5CF6);
const _background = Color(0xFF0F0F0F);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text('PH GLOBAL'),
        actions: [
          ValueListenableBuilder<Set<String>>(
            valueListenable: NotificationService.instance.notifiedAgencyIds,
            builder: (context, notified, _) => IconButton(
              icon: Badge(
                isLabelVisible: notified.isNotEmpty,
                label: Text('${notified.length}'),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () {}, // hook up a notifications screen here later
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
            return _ErrorState(error: snapshot.error.toString(), onRetry: _refresh);
          }

          final agencies = snapshot.data ?? [];
          if (agencies.isEmpty) {
            return const Center(
              child: Text('No agencies available yet.', style: TextStyle(color: Colors.grey)),
            );
          }

          return RefreshIndicator(
            color: _purple,
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: agencies.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      agency.hasSlots
                          ? '${agency.availableDates.length} slot(s) open'
                          : 'No slots open',
                      style: TextStyle(
                        color: agency.hasSlots ? _purple : Colors.grey,
                        fontWeight: agency.hasSlots ? FontWeight.bold : FontWeight.normal,
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
            child: Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}