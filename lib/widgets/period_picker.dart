import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class PeriodPicker extends StatelessWidget {
  final DateTime from;
  final DateTime to;
  final void Function(DateTime from, DateTime to) onChanged;

  const PeriodPicker({
    super.key,
    required this.from,
    required this.to,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context, bool isFrom) async {
    final initial = isFrom ? from : to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('ar'),
    );
    if (picked == null) return;
    if (isFrom) {
      onChanged(picked, to.isBefore(picked) ? picked : to);
    } else {
      onChanged(from.isAfter(picked) ? picked : from, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pick(context, true),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('من', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Text(_fmt(from), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            const Icon(Icons.arrow_back, size: 18, color: AppColors.textMuted),
            Expanded(
              child: InkWell(
                onTap: () => _pick(context, false),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إلى', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Text(_fmt(to), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            // Quick ranges
            PopupMenuButton<String>(
              icon: const Icon(Icons.date_range, color: AppColors.primary),
              onSelected: (v) {
                final now = DateTime.now();
                DateTime f, t = now;
                switch (v) {
                  case 'today':
                    f = now;
                    break;
                  case '7':
                    f = now.subtract(const Duration(days: 6));
                    break;
                  case '30':
                    f = now.subtract(const Duration(days: 29));
                    break;
                  case 'month':
                    f = DateTime(now.year, now.month, 1);
                    break;
                  default:
                    return;
                }
                onChanged(f, t);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'today', child: Text('اليوم')),
                PopupMenuItem(value: '7', child: Text('آخر 7 أيام')),
                PopupMenuItem(value: '30', child: Text('آخر 30 يوم')),
                PopupMenuItem(value: 'month', child: Text('هذا الشهر')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}
