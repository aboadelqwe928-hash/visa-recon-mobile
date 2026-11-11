import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_theme.dart';

class CashierDetailScreen extends StatefulWidget {
  final String cashierName;
  final String? branch;
  final String from;
  final String to;

  const CashierDetailScreen({
    super.key,
    required this.cashierName,
    this.branch,
    required this.from,
    required this.to,
  });

  @override
  State<CashierDetailScreen> createState() => _CashierDetailScreenState();
}

class _CashierDetailScreenState extends State<CashierDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final api = context.read<ApiClient>();
    final sync = context.read<SyncService>();

    try {
      // Try online first
      dynamic result;
      try {
        result = await api.call('r.cashier', {
          'from': widget.from,
          'to': widget.to,
          'q': {
            'name': widget.cashierName,
            if (widget.branch != null) 'branch': widget.branch,
          },
        });
      } catch (_) {
        // offline fallback — we may not have detailed cache; show basic info
        result = null;
      }

      if (result is Map) {
        setState(() {
          _data = Map<String, dynamic>.from(result);
          _loading = false;
        });
      } else {
        // Build minimal view from cashiers list cache
        final list = await sync.getCached('cashiers', from: widget.from, to: widget.to);
        Map<String, dynamic>? row;
        if (list is List) {
          for (final item in list) {
            if (item is Map && item['cashier']?.toString() == widget.cashierName) {
              row = Map<String, dynamic>.from(item);
              break;
            }
          }
        } else if (list is Map && list['rows'] is List) {
          for (final item in list['rows']) {
            if (item is Map && item['cashier']?.toString() == widget.cashierName) {
              row = Map<String, dynamic>.from(item);
              break;
            }
          }
        }

        setState(() {
          _data = row != null ? {'summary': row, 'rows': [], 'offline': true} : null;
          _loading = false;
          if (_data == null) {
            _error = 'مفيش تفاصيل محفوظة للكاشير ده. اعمل مزامنة وأنت على الشبكة.';
          }
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cashierName),
        actions: [
          IconButton(icon: const Icon(Icons.sync), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_off_outlined, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.sync),
                          label: const Text('حاول تاني'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final summary = _data?['summary'] as Map? ?? _data ?? {};
    final rows = _data?['rows'] is List ? _data!['rows'] as List : <dynamic>[];
    final offline = _data?['offline'] == true;

    final diff = summary['diff'] ?? 0;
    final diffN = diff is num ? diff.toDouble() : double.tryParse('$diff') ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (offline)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.cloud_off, size: 18, color: AppColors.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'عرض من البيانات المحفوظة (أوفلاين)',
                    style: TextStyle(fontSize: 12, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),

        // Header card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: Text(
                        widget.cashierName.isNotEmpty ? widget.cashierName.characters.first : '؟',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.cashierName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          if ((summary['branch'] ?? widget.branch) != null)
                            Text(
                              '${summary['branch'] ?? widget.branch}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _metric('سيستم', summary['sys'] ?? summary['system'])),
                    Expanded(child: _metric('بنك', summary['bank'])),
                    Expanded(
                      child: _metric(
                        diffN > 0 ? 'عجز' : (diffN < 0 ? 'زيادة' : 'الفرق'),
                        diffN.abs(),
                        color: diffN > 0
                            ? AppColors.danger
                            : (diffN < 0 ? AppColors.success : AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (rows.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'التفاصيل (${rows.length})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 10),
          ...rows.map((r) {
            final row = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(row['day']?.toString() ?? '—'),
                subtitle: Text(
                  [
                    if (row['mach'] != null) 'ماكينة ${row['mach']}',
                    if (row['order'] != null) 'أوردر ${row['order']}',
                  ].join(' · '),
                ),
                trailing: Text(
                  _fmt(row['amt'] ?? row['net'] ?? row['amount']),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            );
          }),
        ] else if (!offline) ...[
          const SizedBox(height: 24),
          const Center(
            child: Text('مفيش حركات تفصيلية في الفترة دي', style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ],
    );
  }

  Widget _metric(String label, dynamic value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(
          _fmt(value),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: color ?? AppColors.text,
          ),
        ),
      ],
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '—';
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    if (n == null) return '$v';
    return n.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }
}
