import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Simple comparison bars: سيستم vs بنك
class SysBankChart extends StatelessWidget {
  final double sys;
  final double bank;

  const SysBankChart({super.key, required this.sys, required this.bank});

  @override
  Widget build(BuildContext context) {
    final maxY = [sys.abs(), bank.abs(), 1.0].reduce((a, b) => a > b ? a : b) * 1.15;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('سيستم × بنك', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, gIdx, rod, rIdx) {
                        final label = group.x == 0 ? 'سيستم' : 'بنك';
                        return BarTooltipItem(
                          '$label\n${_fmt(rod.toY)}',
                          const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (v, m) => Text(
                          _short(v),
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, m) {
                          final labels = ['سيستم', 'بنك'];
                          final i = v.toInt();
                          if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(labels[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(color: AppColors.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [
                      BarChartRodData(
                        toY: sys.abs(),
                        width: 36,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        color: AppColors.primary,
                      ),
                    ]),
                    BarChartGroupData(x: 1, barRods: [
                      BarChartRodData(
                        toY: bank.abs(),
                        width: 36,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        color: AppColors.primaryDark,
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  String _short(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}م';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}أ';
    return v.toStringAsFixed(0);
  }
}

/// Daily difference line chart. Expects list of {day, diff} maps.
class DailyDiffChart extends StatelessWidget {
  final List<Map<String, dynamic>> points;

  const DailyDiffChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const SizedBox.shrink();
    }

    final values = points.map((p) {
      final d = p['diff'];
      return d is num ? d.toDouble() : double.tryParse('$d') ?? 0.0;
    }).toList();

    final maxAbs = values.map((v) => v.abs()).fold<double>(1, (a, b) => a > b ? a : b);
    final maxY = maxAbs * 1.2;
    final minY = -maxY;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('الفرق اليومي (سيستم − بنك)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        final day = points[s.x.toInt()]['day']?.toString() ?? '';
                        return LineTooltipItem(
                          '$day\n${s.y.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList(),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: v == 0 ? AppColors.textMuted.withOpacity(0.4) : AppColors.border,
                      strokeWidth: v == 0 ? 1.2 : 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, m) => Text(
                          v == 0 ? '0' : v.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (points.length / 4).clamp(1, 10).toDouble(),
                        getTitlesWidget: (v, m) {
                          final i = v.toInt();
                          if (i < 0 || i >= points.length) return const SizedBox.shrink();
                          final day = points[i]['day']?.toString() ?? '';
                          final short = day.length >= 10 ? day.substring(5) : day; // MM-DD
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(short, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
                      ],
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: points.length <= 14,
                        getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                          radius: 3,
                          color: values[i] > 0 ? AppColors.danger : (values[i] < 0 ? AppColors.success : AppColors.primary),
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  _LegendDot(color: AppColors.danger, label: 'عجز'),
                  SizedBox(width: 12),
                  _LegendDot(color: AppColors.success, label: 'زيادة'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}
