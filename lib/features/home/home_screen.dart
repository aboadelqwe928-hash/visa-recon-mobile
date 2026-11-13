import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/home_service.dart';
import '../../core/services/nav_bus.dart';

/// ألوان زي البرنامج على الكمبيوتر: الزيادة أخضر والعجز أحمر، والكاش دهبي
class _C {
  static const bg = Color(0xFFF3F5F8);
  static const surface = Colors.white;
  static const line = Color(0xFFE4E9EF);
  static const fg = Color(0xFF0F1B2D);
  static const muted = Color(0xFF66748A);
  static const accent = Color(0xFF0A6B58);
  static const good = Color(0xFF167A42);
  static const goodSoft = Color(0xFFE2F3E8);
  static const bad = Color(0xFFC0352A);
  static const badSoft = Color(0xFFFBE7E4);
  static const warn = Color(0xFF9A6700);
  static const warnSoft = Color(0xFFFBF0D6);
  static const gold = Color(0xFFB88A2E);
  static const goldLight = Color(0xFFE9C46A);
  static const goldSoft = Color(0xFFF7EFDC);
}

final _nf = NumberFormat('#,##0.##', 'en');
num _n(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);
String _fmt(dynamic v) => _nf.format(_n(v));
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) {
  if (v is! List) return <Map<String, dynamic>>[];
  final out = <Map<String, dynamic>>[];
  for (final e in v) {
    if (e is Map) out.add(Map<String, dynamic>.from(e));
  }
  return out;
}

/// الشاشة الرئيسية: ملخص آخر يوم، والتنبيهات، واختصارات بتفتح السيستم على الشاشة المطلوبة.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final h = context.read<HomeService>();
      h.init().then((_) => h.refresh());
    });
  }

  void _open(String view, {String? day}) => context.read<NavBus>().openSystem(view, day: day);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final h = context.watch<HomeService>();
    final auth = context.watch<AuthService>();
    final d = h.data;
    final perms = (d != null && d['user'] is Map && (d['user'] as Map)['perms'] is List)
        ? List<String>.from(((d['user'] as Map)['perms'] as List).map((e) => '$e'))
        : <String>[];

    final children = <Widget>[];
    if (d != null) {
      if (h.error != null) children.add(_offlineBanner(h));
      if (d['cash'] is Map) children.add(_cashCard(d));
      final alerts = _l(d['alerts']);
      if (alerts.isNotEmpty) children.add(_alerts(alerts));
      if (d['total'] is Map) children.add(_totals(_m(d['total'])));
      final trend = _l(d['trend']);
      if (trend.length > 1) children.add(_trend(trend));
      final brs = _l(d['branches']);
      if (brs.isNotEmpty) children.add(_branches(brs, d['day']?.toString()));
      if (d['cash'] is Map && !(d['total'] is Map)) {
        final cb = _l(_m(d['cash'])['branches']);
        if (cb.length > 1) children.add(_cashBranches(cb));
      }
      children.add(_actions(perms, d['day']?.toString()));
      children.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'البرنامج ${d['version'] ?? ''}${h.at != null ? ' · آخر تحديث ${DateFormat('h:mm a', 'en').format(h.at!)}' : ''}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: _C.muted),
        ),
      ));
    }

    return Scaffold(
      backgroundColor: _C.bg,
      body: RefreshIndicator(
        color: _C.accent,
        onRefresh: () => h.refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(context, h, auth, d)),
            if (d == null)
              SliverFillRemaining(hasScrollBody: false, child: _empty(h))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    for (final w in children) Padding(padding: const EdgeInsets.only(bottom: 12), child: w),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------- الهيدر
  Widget _header(BuildContext context, HomeService h, AuthService auth, Map<String, dynamic>? d) {
    final user = _m(d?['user']);
    final name = (user['name'] ?? auth.user?.displayName ?? '').toString();
    final role = (user['roleLabel'] ?? '').toString();
    final day = d?['day']?.toString() ?? '';
    final locked = d?['locked'] is Map;
    final online = d != null && h.error == null && !h.fromCache;
    String dayLabel = day;
    try {
      if (day.isNotEmpty) dayLabel = DateFormat('EEEE d MMMM', 'ar').format(DateTime.parse('${day}T12:00:00'));
    } catch (_) {}
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF4A3A12), Color(0xFF2A2109), Color(0xFF18130A)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0x33E9C46A),
                    child: Text(
                      name.isNotEmpty ? name.characters.first : '؟',
                      style: const TextStyle(color: _C.goldLight, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('أهلاً، $name',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        if (role.isNotEmpty) Text(role, style: const TextStyle(color: Color(0xFFD8C79C), fontSize: 12.5)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: h.loading ? null : () => h.refresh(),
                    tooltip: 'تحديث',
                    icon: h.loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _C.goldLight))
                        : const Icon(Icons.refresh_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (day.isNotEmpty) _chip(Icons.calendar_today_rounded, dayLabel),
                  if (day.isNotEmpty) _chip(locked ? Icons.lock_rounded : Icons.lock_open_rounded, locked ? 'اليوم مقفول' : 'اليوم مفتوح', hi: locked),
                  _chip(online ? Icons.wifi_rounded : Icons.cloud_off_rounded, online ? 'متصل بالكمبيوتر' : 'مش متصل'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData i, String t, {bool hi = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hi ? const Color(0x29E9C46A) : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: hi ? const Color(0x73E9C46A) : const Color(0x24FFFFFF)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 14, color: hi ? _C.goldLight : const Color(0xFFD8C79C)),
          const SizedBox(width: 6),
          Text(t, style: TextStyle(color: hi ? _C.goldLight : const Color(0xFFE9E2CF), fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _empty(HomeService h) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: h.loading
            ? const CircularProgressIndicator()
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(h.oldServer ? Icons.system_update_alt_rounded : Icons.cloud_off_rounded, size: 52, color: _C.gold),
                const SizedBox(height: 12),
                Text(h.oldServer ? 'حدّث البرنامج على الكمبيوتر' : 'مفيش بيانات لسه',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  h.oldServer
                      ? 'الشاشة دي محتاجة البرنامج 2.8.0 أو أحدث. تقدر تستخدم تبويب "السيستم" عادي.'
                      : (h.error ?? 'اتصل بالكمبيوتر على نفس الواي فاي واسحب لتحت للتحديث.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _C.muted),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: () => h.refresh(), icon: const Icon(Icons.refresh), label: const Text('حاول تاني')),
              ]),
      ),
    );
  }

  Widget _offlineBanner(HomeService h) {
    final t = h.at != null ? DateFormat('d/M h:mm a', 'en').format(h.at!) : '';
    return _box(
      color: _C.warnSoft,
      border: const Color(0x599A6700),
      child: Row(children: [
        Icon(h.oldServer ? Icons.system_update_alt_rounded : Icons.cloud_off_rounded, color: _C.warn),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            h.oldServer ? 'البرنامج على الكمبيوتر محتاج تحديث لـ 2.8.0' : 'مش متصل بالكمبيوتر — دي آخر بيانات${t.isNotEmpty ? ' من $t' : ''}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(onPressed: () => h.refresh(), child: const Text('حدّث')),
      ]),
    );
  }

  // ---------------- استلام الكاش
  Widget _cashCard(Map<String, dynamic> d) {
    final c = _m(d['cash']);
    final n = _n(c['n']).toInt(), done = _n(c['done']).toInt();
    final pct = n > 0 ? done / n : 0.0;
    final diff = _n(c['diff']);
    final ccp = _n(c['ccPending']).toInt();
    return _card(
      title: 'استلام الكاش',
      icon: Icons.payments_rounded,
      trailing: TextButton.icon(
        onPressed: () => _open('cash', day: d['day']?.toString()),
        icon: const Icon(Icons.open_in_new_rounded, size: 16),
        label: const Text('افتح الاستلام'),
      ),
      child: Column(children: [
        Row(children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 92,
                height: 92,
                child: CircularProgressIndicator(
                  value: pct.toDouble(),
                  strokeWidth: 9,
                  backgroundColor: const Color(0xFFEEF2F6),
                  color: pct >= 1 ? _C.good : _C.gold,
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${(pct * 100).round()}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text('$done من $n', style: const TextStyle(fontSize: 10.5, color: _C.muted)),
              ]),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(children: [
              _kv('المطلوب كاش', _fmt(c['expected'])),
              _kv('اللي اتسلم', _fmt(c['received']), color: _C.gold),
              _kv('الفرق (للي اتسجل)', diff == 0 ? 'مظبوط' : '${diff > 0 ? 'زيادة' : 'عجز'} ${_fmt(diff.abs())}',
                  color: diff > 0 ? _C.good : diff < 0 ? _C.bad : _C.muted),
              _kv('مستني تسجيل', n - done > 0 ? '${n - done} كاشير · ${_fmt(c['pendingAmt'])}' : 'كله متسجل',
                  color: n - done > 0 ? _C.warn : _C.good),
            ]),
          ),
        ]),
        if (ccp > 0) ...[
          const SizedBox(height: 10),
          _pill(Icons.support_agent_rounded, '$ccp أوردر كول سنتر مستني قرار · ${_fmt(c['ccPendingAmt'])}', _C.warn, _C.warnSoft,
              onTap: () => _open('cash', day: d['day']?.toString())),
        ],
      ]),
    );
  }

  Widget _cashBranches(List<Map<String, dynamic>> bs) {
    return _card(
      title: 'الاستلام في الفروع',
      icon: Icons.store_rounded,
      child: Column(
        children: bs.map((b) {
          final n = _n(b['n']), dn = _n(b['done']);
          final p = n > 0 ? (dn / n).toDouble() : 0.0;
          final diff = _n(b['diff']);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${b['branch']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${dn.toInt()}/${n.toInt()}', style: const TextStyle(color: _C.muted, fontSize: 12)),
                const SizedBox(width: 10),
                if (dn > 0)
                  Text(diff == 0 ? '✓' : '${diff > 0 ? '+' : '−'} ${_fmt(diff.abs())}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: diff > 0 ? _C.good : diff < 0 ? _C.bad : _C.muted)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: p,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFEEF2F6),
                  color: p >= 1 ? _C.good : _C.gold,
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ---------------- التنبيهات
  Widget _alerts(List<Map<String, dynamic>> as) {
    return _card(
      title: 'محتاج انتباهك',
      icon: Icons.notifications_active_rounded,
      child: Column(
        children: as.map((a) {
          final lv = '${a['level']}';
          final fg = lv == 'bad' ? _C.bad : lv == 'warn' ? _C.warn : _C.accent;
          final bg = lv == 'bad' ? _C.badSoft : lv == 'warn' ? _C.warnSoft : const Color(0xFFE3F2EE);
          final view = a['view']?.toString();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: view == null ? null : () => _open(view, day: a['day']?.toString()),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(lv == 'bad' ? Icons.error_rounded : lv == 'warn' ? Icons.warning_amber_rounded : Icons.info_rounded, color: fg),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${a['title']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        if ((a['sub'] ?? '').toString().isNotEmpty)
                          Text('${a['sub']}', style: const TextStyle(color: _C.muted, fontSize: 12)),
                      ]),
                    ),
                    if (view != null) Icon(Icons.chevron_left_rounded, color: fg),
                  ]),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------- الإجمالي
  Widget _totals(Map<String, dynamic> t) {
    Widget tile(String k, dynamic v, {bool big = false}) {
      final x = _n(v);
      final c = x > 0 ? _C.good : x < 0 ? _C.bad : _C.muted;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: big ? (x < 0 ? _C.badSoft : x > 0 ? _C.goodSoft : const Color(0xFFF6F8FA)) : const Color(0xFFF6F8FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: const TextStyle(fontSize: 11.5, color: _C.muted)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(_fmt(x.abs()), style: TextStyle(fontSize: big ? 20 : 17, fontWeight: FontWeight.w800, color: c)),
            ),
            Text(x > 0 ? 'زيادة' : x < 0 ? 'عجز' : 'مظبوط', style: TextStyle(fontSize: 11, color: c)),
          ]),
        ),
      );
    }

    final pend = _n(t['pendingAmt']);
    return _card(
      title: 'نتيجة اليوم (فيزا + كاش)',
      icon: Icons.account_balance_wallet_rounded,
      trailing: TextButton(onPressed: () => _open('combined', day: _dayOf()), child: const Text('التقرير الإجمالي')),
      child: Column(children: [
        Row(children: [
          tile('صافي الفيزا', t['visaNet']),
          const SizedBox(width: 8),
          tile('صافي الكاش', t['cashNet']),
          const SizedBox(width: 8),
          tile('الإجمالي', t['net'], big: true),
        ]),
        if (pend > 0) ...[
          const SizedBox(height: 8),
          _pill(Icons.hourglass_bottom_rounded, 'كاش مستني تسجيل ${_fmt(pend)} (مش داخل في الحساب)', _C.warn, _C.warnSoft),
        ],
      ]),
    );
  }

  String? _dayOf() => context.read<HomeService>().data?['day']?.toString();

  // ---------------- آخر 7 أيام (أعمدة بسيطة: فوق الخط زيادة وتحته عجز)
  Widget _trend(List<Map<String, dynamic>> tr) {
    final nets = tr.map((x) => _n(x['visaNet']) + _n(x['cashNet'])).toList();
    final mx = nets.fold<num>(1, (a, b) => b.abs() > a ? b.abs() : a);
    return _card(
      title: 'آخر ${tr.length} أيام',
      icon: Icons.bar_chart_rounded,
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(tr.length, (i) {
            final v = nets[i];
            final f = (v.abs() / mx).toDouble();
            final day = '${tr[i]['day']}';
            final lbl = day.length >= 10 ? '${int.tryParse(day.substring(8, 10)) ?? ''}/${int.tryParse(day.substring(5, 7)) ?? ''}' : day;
            final col = v >= 0 ? _C.good : _C.bad;
            return Expanded(
              child: Tooltip(
                message: '$day\n${v >= 0 ? 'زيادة' : 'عجز'} ${_fmt(v.abs())}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: v > 0 ? _bar(f, col, top: true) : const SizedBox.shrink(),
                      ),
                    ),
                    Container(height: 1, color: _C.line),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: v < 0 ? _bar(f, col, top: false) : const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(lbl, style: const TextStyle(fontSize: 10, color: _C.muted)),
                  ]),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _bar(double f, Color c, {required bool top}) => FractionallySizedBox(
        heightFactor: f.clamp(0.04, 1.0),
        widthFactor: 0.7,
        child: Container(
          decoration: BoxDecoration(
            color: c,
            borderRadius: top ? const BorderRadius.vertical(top: Radius.circular(6)) : const BorderRadius.vertical(bottom: Radius.circular(6)),
          ),
        ),
      );

  // ---------------- الفروع
  Widget _branches(List<Map<String, dynamic>> bs, String? day) {
    final show = bs.take(8).toList();
    return _card(
      title: 'الفروع (الأكبر عجز الأول)',
      icon: Icons.store_rounded,
      trailing: TextButton(onPressed: () => _open('combined', day: day), child: const Text('الكل')),
      child: Column(
        children: show.map((b) {
          final net = _n(b['net']);
          final c = net > 0 ? _C.good : net < 0 ? _C.bad : _C.muted;
          return InkWell(
            onTap: () => _open('combined', day: day),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Container(width: 4, height: 34, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${b['branch']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('فيزا ${_sg(b['visaNet'])} · كاش ${_sg(b['cashNet'])}', style: const TextStyle(fontSize: 11.5, color: _C.muted)),
                  ]),
                ),
                Text(net == 0 ? '✓' : '${net > 0 ? '+' : '−'} ${_fmt(net.abs())}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: c, fontSize: 15)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _sg(dynamic v) {
    final x = _n(v);
    return x == 0 ? '0' : '${x > 0 ? '+' : '−'}${_fmt(x.abs())}';
  }

  // ---------------- اختصارات
  Widget _actions(List<String> perms, String? day) {
    final items = <List<dynamic>>[
      if (perms.contains('cash')) ['cash', 'استلام الكاش', Icons.payments_rounded, _C.gold],
      if (perms.contains('view')) ['dashboard', 'لوحة التحكم', Icons.space_dashboard_rounded, _C.accent],
      if (perms.contains('view')) ['combined', 'التقرير الإجمالي', Icons.summarize_rounded, _C.accent],
      if (perms.contains('view')) ['final', 'الزيادة والعجز', Icons.trending_up_rounded, _C.accent],
      if (perms.contains('view')) ['cashrep', 'تقرير الكاش', Icons.receipt_long_rounded, _C.gold],
      if (perms.contains('view')) ['search', 'بحث عن عملية', Icons.search_rounded, _C.accent],
      if (perms.contains('whatsapp')) ['whatsapp', 'إرسال واتساب', Icons.send_rounded, const Color(0xFF1DA851)],
      if (perms.contains('view')) ['data', 'البيانات والأيام المقفولة', Icons.lock_clock_rounded, _C.muted],
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return _card(
      title: 'اختصارات',
      icon: Icons.apps_rounded,
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.82,
        children: items.map((it) {
          final c = it[3] as Color;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _open(it[0] as String, day: it[0] == 'cash' || it[0] == 'combined' || it[0] == 'final' ? day : null),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(it[2] as IconData, color: c),
              ),
              const SizedBox(height: 6),
              Text(it[1] as String,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.25)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ---------------- أدوات
  Widget _card({required String title, required IconData icon, required Widget child, Widget? trailing}) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
        boxShadow: const [BoxShadow(color: Color(0x0D0F1B2D), blurRadius: 8, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _C.goldSoft, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 18, color: _C.gold),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _C.fg))),
          if (trailing != null) trailing,
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _box({required Widget child, required Color color, required Color border}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
        child: child,
      );

  Widget _kv(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: const TextStyle(fontSize: 12.5, color: _C.muted))),
          Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color ?? _C.fg)),
        ]),
      );

  Widget _pill(IconData i, String t, Color fg, Color bg, {VoidCallback? onTap}) => Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              Icon(i, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(child: Text(t, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12.5))),
              if (onTap != null) Icon(Icons.chevron_left_rounded, color: fg, size: 18),
            ]),
          ),
        ),
      );
}
