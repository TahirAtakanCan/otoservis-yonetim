import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/providers/auth_provider.dart';
import 'package:otoservis_app/utils/constants.dart';
import 'package:otoservis_app/widgets/common/app_sidebar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _firestore = FirebaseFirestore.instance;

  int _vehiclesToday = 0;
  int _criticalParts = 0;
  double _revenueToday = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final startTs = Timestamp.fromDate(start);
    final endTs = Timestamp.fromDate(end);

    try {
      final serviceQuery = await _firestore
          .collection(FirestoreCollections.serviceRecords)
          .where('date', isGreaterThanOrEqualTo: startTs)
          .where('date', isLessThan: endTs)
          .get();

      double revenue = 0;
      for (final doc in serviceQuery.docs) {
        final g = doc.data()['grandTotal'];
        if (g is num) revenue += g.toDouble();
      }

      final inventorySnap =
          await _firestore.collection(FirestoreCollections.inventory).get();

      var critical = 0;
      for (final doc in inventorySnap.docs) {
        final d = doc.data();
        final q = (d['quantity'] as num?)?.toInt() ?? 0;
        final min = (d['minStockAlert'] as num?)?.toInt() ?? 0;
        if (q <= min) critical++;
      }

      if (!mounted) return;
      setState(() {
        _vehiclesToday = serviceQuery.docs.length;
        _criticalParts = critical;
        _revenueToday = revenue;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onVehiclesCardTap(BuildContext context) {
    context.go('/vehicle-search');
  }

  void _onCriticalStockTap(BuildContext context) {
    final role = context.read<AuthProvider>().currentUser?.role;
    if (role == 'admin') {
      context.go('/inventory');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stok yönetimine yalnızca yöneticiler erişebilir.'),
        ),
      );
    }
  }

  void _onRevenueCardTap(BuildContext context) {
    context.go('/reports');
  }

  @override
  Widget build(BuildContext context) {
    final userName = context.watch<AuthProvider>().currentUser?.name ?? '';
    final greeting = userName.isNotEmpty ? 'Hoş geldiniz, $userName' : 'Hoş geldiniz';
    final dateStr = DateFormat.yMMMMEEEEd('tr').format(DateTime.now());

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSidebar(),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFFF1F5F9),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                    const SizedBox(height: 28),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Veriler yüklenirken hata: $_error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final maxW = constraints.maxWidth;
                          final cardWidth = maxW > 900
                              ? (maxW - 32) / 3
                              : (maxW > 520 ? (maxW - 16) / 2 : maxW);
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: cardWidth.clamp(220, maxW),
                                child: _SummaryCard(
                                  title: 'Bugün gelen araç',
                                  value: '$_vehiclesToday',
                                  subtitle: 'Bugünkü servis kayıtları',
                                  icon: Icons.directions_car_filled_outlined,
                                  color: const Color(0xFF2563EB),
                                  onTap: () => _onVehiclesCardTap(context),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth.clamp(220, maxW),
                                child: _SummaryCard(
                                  title: 'Kritik stok',
                                  value: '$_criticalParts',
                                  subtitle: 'Min. stok altı parça',
                                  icon: Icons.warning_amber_rounded,
                                  color: const Color(0xFFD97706),
                                  onTap: () => _onCriticalStockTap(context),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth.clamp(220, maxW),
                                child: _SummaryCard(
                                  title: 'Bugünkü ciro',
                                  value: NumberFormat.currency(
                                    locale: 'tr_TR',
                                    symbol: '₺',
                                  ).format(_revenueToday),
                                  subtitle: 'Tamamlanan kayıtlar toplamı',
                                  icon: Icons.payments_outlined,
                                  color: const Color(0xFF059669),
                                  onTap: () => _onRevenueCardTap(context),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black45,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
