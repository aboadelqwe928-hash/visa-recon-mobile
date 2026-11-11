import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/period_picker.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/dashboard_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  late DateTime _from;
  late DateTime _to;
  List<Map<String, dynamic>> _dailyPoints = [];

  double _toD(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

  /// نقط الرسم اليومي من بيانات لوحة التحكم المحفوظة (series: [{day, diff}])
  Future<List<Map<String, dynamic>>> _buildDailyPoints(SyncService sync, String from, String to) async {
    final d = await sync.getCached('dashboard', from: from, to: to);
    final s = d is Map ? d['series'] : null;
    if (s is! List) return <Map<String, dynamic>>[];
    return s
        .whereType<Map>()
        .map((e) => <String, dynamic>{'day': e['day'], 'diff': e['diff']})
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = now;
    _from = now.subtract(const Duration(days: 6));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load({bool forceSync = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final sync = context.read<SyncService>();
    final from = _fmt(_from);
    final to = _fmt(_to);

    try {
      if (forceSync) {
        await sync.forceSync(from: from, to: to);
        final fresh = await sync.getCached('dashboard', from: from, to: to);
        final points = await _buildDailyPoints(sync, from, to);
        if (mounted) {
          setState(() {
            if (fresh != null) {
              _data = Map<String, dynamic>.from(fresh is Map ? fresh : {});
            }
            _dailyPoints = points;
            _loading = false;
            if (_data == null) {
              _error = 'مفيش بيانات. تأكد من الاتصال بالسيرفر.';
            }
          });
        }
        return;
      } else {
        // Try cache first, then background sync
        final cached = await sync.getCached('dashboard', from: from, to: to);
        if (cached != null) {
          final points = await _buildDailyPoints(sync, from, to);
          setState(() {
            _data = Map<String, dynamic>.from(cached is Map ? cached : {});
            _dailyPoints = points;
            _loading = false;
          });
        }
        // Always try to refresh if possible
        await sync.syncIfPossible(from: from, to: to, silent: true);
        final fresh = await sync.getCached('dashboard', from: from, to: to);
        if (fresh != null && mounted) {
          final points = await _buildDailyPoints(sync, from, to);
          setState(() {
            _data = Map<String, dynamic>.from(fresh is Map ? fresh : {});
            _dailyPoints = points;
            _loading = false;
          });
        } else if (_data == null && mounted) {
          setState(() {
            _loading = false;
            _error = 'مفيش بيانات محفوظة. ادخل على الشبكة المحلية عشان تعمل مزامنة.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kpi = _data?['kpi'] as Map? ?? {};
    final prev = _data?['prev'] as Map?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'مزامنة الآن',
            onPressed: () => _load(forceSync: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(forceSync: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PeriodPicker(
              from: _from,
              to: _to,
              onChanged: (f, t) {
                setState(() {
                  _from = f;
                  _to = t;
                });
                _load();
              },
            ),
            const SizedBox(height: 16),

            if (_loading && _data == null)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _data == null)
              _ErrorBox(message: _error!, onRetry: () => _load(forceSync: true))
            else ...[
              // KPI Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  KpiCard(
                    title: 'صافي السيستم',
                    value: _num(kpi['sys']),
                    color: AppColors.primary,
                    icon: Icons.point_of_sale,
                  ),
                  KpiCard(
                    title: 'صافي البنك',
                    value: _num(kpi['bank']),
                    color: AppColors.primaryDark,
                    icon: Icons.account_balance,
                  ),
                  KpiCard(
                    title: 'الفرق',
                    value: _num(kpi['diff']),
                    color: _diffColor(kpi['diff']),
                    icon: Icons.compare_arrows,
                  ),
                  KpiCard(
                    title: 'مشاكل',
                    value: '${kpi['problems'] ?? 0}',
                    color: AppColors.danger,
                    icon: Icons.warning_amber_rounded,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              SysBankChart(
                sys: _toD(kpi['sys']),
                bank: _toD(kpi['bank']),
              ),
              if (_dailyPoints.isNotEmpty) ...[
                const SizedBox(height: 12),
                DailyDiffChart(points: _dailyPoints),
              ],

              if (prev != null && prev['kpi'] != null) ...[
                const SizedBox(height: 20),
                Text(
                  'مقارنة بالفترة السابقة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _PrevRow(prev: Map<String, dynamic>.from(prev)),
              ],

              const SizedBox(height: 24),
              Text(
                'ملخص سريع',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              _InfoTile(label: 'عدد الفروع', value: '${kpi['branches'] ?? '—'}'),
              _InfoTile(label: 'عدد الكاشيرات', value: '${kpi['cashiers'] ?? '—'}'),
              _InfoTile(label: 'عمليات السيستم', value: '${kpi['nSys'] ?? '—'}'),
              _InfoTile(label: 'عمليات البنك', value: '${kpi['nBank'] ?? '—'}'),
            ],
          ],
        ),
      ),
    );
  }

  String _num(dynamic v) {
    if (v == null) return '—';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    return n.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  Color _diffColor(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    if (n > 0) return AppColors.danger; // عجز
    if (n < 0) return AppColors.success; // زيادة
    return AppColors.textMuted;
  }
}

class _PrevRow extends StatelessWidget {
  final Map<String, dynamic> prev;
  const _PrevRow({required this.prev});

  @override
  Widget build(BuildContext context) {
    final kpi = prev['kpi'] as Map? ?? {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: _mini('السيستم', kpi['sys'])),
            Expanded(child: _mini('البنك', kpi['bank'])),
            Expanded(child: _mini('الفرق', kpi['diff'])),
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    final txt = n.toStringAsFixed(0);
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(txt, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(label),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.sync),
            label: const Text('حاول تاني'),
          ),
        ],
      ),
    );
  }
}
