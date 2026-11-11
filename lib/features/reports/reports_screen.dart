import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/period_picker.dart';
import 'cashier_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late DateTime _from;
  late DateTime _to;

  List<dynamic> _branches = [];
  List<dynamic> _cashiers = [];
  List<dynamic> _balance = [];
  List<dynamic> _gaps = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    final now = DateTime.now();
    _to = now;
    _from = now.subtract(const Duration(days: 6));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final sync = context.read<SyncService>();
    final from = _fmt(_from);
    final to = _fmt(_to);

    try {
      if (force) await sync.forceSync(from: from, to: to);

      final b = await sync.getCached('branches', from: from, to: to);
      final c = await sync.getCached('cashiers', from: from, to: to);
      final bal = await sync.getCached('balance', from: from, to: to);
      final g = await sync.getCached('gaps', from: from, to: to);

      // background refresh
      if (!force) {
        sync.syncIfPossible(from: from, to: to, silent: true).then((_) async {
          if (!mounted) return;
          final b2 = await sync.getCached('branches', from: from, to: to);
          final c2 = await sync.getCached('cashiers', from: from, to: to);
          final bal2 = await sync.getCached('balance', from: from, to: to);
          final g2 = await sync.getCached('gaps', from: from, to: to);
          setState(() {
            if (b2 != null) _branches = _asList(b2, 'rows');
            if (c2 != null) _cashiers = _asList(c2);
            if (bal2 != null) _balance = _asList(bal2);
            if (g2 != null) _gaps = _asList(g2);
          });
        });
      }

      setState(() {
        _branches = _asList(b, 'rows');
        _cashiers = _asList(c);
        _balance = _asList(bal);
        _gaps = _asList(g);
        _loading = false;
        if (_branches.isEmpty && _cashiers.isEmpty && _balance.isEmpty) {
          _error = 'مفيش بيانات محفوظة للفترة دي. اعمل مزامنة وأنت على الشبكة.';
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<dynamic> _asList(dynamic data, [String? key]) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map && key != null && data[key] is List) return data[key];
    if (data is Map) return [data];
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'الفروع'),
            Tab(text: 'الكاشيرات'),
            Tab(text: 'الزيادة والعجز'),
            Tab(text: 'الفجوات'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => _load(force: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: PeriodPicker(
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
          ),
          Expanded(
            child: _loading && _branches.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _BranchesTab(rows: _branches),
                      _CashiersTab(rows: _cashiers, from: _fmt(_from), to: _fmt(_to)),
                      _BalanceTab(rows: _balance),
                      _GapsTab(rows: _gaps),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _BranchesTab extends StatelessWidget {
  final List<dynamic> rows;
  const _BranchesTab({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = rows[i] is Map ? Map<String, dynamic>.from(rows[i]) : <String, dynamic>{};
        final name = r['branch']?.toString() ?? '—';
        final diff = r['diff'] ?? r['Diff'] ?? 0;
        final n = diff is num ? diff.toDouble() : double.tryParse('$diff') ?? 0;
        return Card(
          child: ListTile(
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('سيستم: ${_fmt(r['sys'])}  ·  بنك: ${_fmt(r['bank'])}'),
            trailing: Text(
              _fmt(n),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: n > 0 ? AppColors.danger : (n < 0 ? AppColors.success : AppColors.textMuted),
              ),
            ),
          ),
        );
      },
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '—';
    final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return n.toStringAsFixed(0);
  }
}

class _CashiersTab extends StatelessWidget {
  final List<dynamic> rows;
  final String from;
  final String to;
  const _CashiersTab({required this.rows, required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = rows[i] is Map ? Map<String, dynamic>.from(rows[i]) : <String, dynamic>{};
        final name = r['cashier']?.toString() ?? '—';
        final branch = r['branch']?.toString() ?? '';
        final diff = r['diff'] ?? 0;
        final n = diff is num ? diff.toDouble() : double.tryParse('$diff') ?? 0;
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CashierDetailScreen(
                    cashierName: name,
                    branch: branch.isEmpty ? null : branch,
                    from: from,
                    to: to,
                  ),
                ),
              );
            },
            child: ListTile(
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(branch),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        n > 0 ? 'عجز' : (n < 0 ? 'زيادة' : 'متزن'),
                        style: TextStyle(
                          fontSize: 11,
                          color: n > 0 ? AppColors.danger : (n < 0 ? AppColors.success : AppColors.textMuted),
                        ),
                      ),
                      Text(
                        n.abs().toStringAsFixed(0),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: n > 0 ? AppColors.danger : (n < 0 ? AppColors.success : AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_left, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BalanceTab extends StatelessWidget {
  final List<dynamic> rows;
  const _BalanceTab({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = rows[i] is Map ? Map<String, dynamic>.from(rows[i]) : <String, dynamic>{};
        final branch = r['branch']?.toString() ?? '—';
        final over = r['over'] ?? r['plus'] ?? 0;
        final under = r['under'] ?? r['minus'] ?? 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(branch, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _chip('زيادة', over, AppColors.success),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _chip('عجز', under, AppColors.danger),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label, dynamic v, Color c) {
    final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: c, fontSize: 12)),
          Text(n.toStringAsFixed(0), style: TextStyle(color: c, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _GapsTab extends StatelessWidget {
  final List<dynamic> rows;
  const _GapsTab({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty(text: 'مفيش فجوات في الفترة دي');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = rows[i] is Map ? Map<String, dynamic>.from(rows[i]) : <String, dynamic>{};
        return Card(
          child: ListTile(
            leading: const Icon(Icons.link_off, color: AppColors.warning),
            title: Text(r['branch']?.toString() ?? '—'),
            subtitle: Text('${r['day'] ?? ''} · ${r['cashier'] ?? r['mach'] ?? ''}'),
            trailing: Text(
              '${r['amt'] ?? r['amount'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({this.text = 'مفيش بيانات'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
      ),
    );
  }
}
