import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/offline_service.dart';
import '../../core/theme/app_theme.dart';

/// المزامنة والنسخ الاحتياطي: نسخة كاملة من السيستم على الموبايل.
class SyncBackupScreen extends StatefulWidget {
  const SyncBackupScreen({super.key});

  @override
  State<SyncBackupScreen> createState() => _SyncBackupScreenState();
}

class _SyncBackupScreenState extends State<SyncBackupScreen> {
  List<BackupFile> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final l = await context.read<OfflineService>().backups();
    if (mounted) setState(() {
      _list = l;
      _loading = false;
    });
  }

  String _ago(DateTime? t) {
    if (t == null) return 'لسه';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'دلوقتي';
    if (d.inMinutes < 60) return 'من ${d.inMinutes} دقيقة';
    if (d.inHours < 24) return 'من ${d.inHours} ساعة';
    return 'من ${d.inDays} يوم';
  }

  String _size(int b) {
    if (b <= 0) return '—';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _dt(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${t.day}/${t.month}/${t.year}  $h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'ص' : 'م'}';
  }

  Future<void> _sync({bool backup = false}) async {
    final off = context.read<OfflineService>();
    final ok = await off.sync(forceBackup: backup);
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? (backup ? 'تمت المزامنة وحفظ نسخة احتياطية' : 'تمت المزامنة') : (off.error ?? 'المزامنة ما تمتش')),
      backgroundColor: ok ? AppColors.success : AppColors.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final off = context.watch<OfflineService>();
    final snap = off.snapAt == null ? null : DateTime.tryParse(off.snapAt!)?.toLocal();
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: () => _sync(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _hero(context, off, snap)),
            if (off.viewingBackup)
              SliverToBoxAdapter(
                child: _card(
                  color: AppColors.warning.withOpacity(.08),
                  child: Row(children: [
                    const Icon(Icons.history, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(child: Text('السيستم بيعرض نسخة احتياطية (${snap == null ? '' : _dt(snap)})')),
                    TextButton(onPressed: () => off.closeBackupView(), child: const Text('رجوع لآخر مزامنة')),
                  ]),
                ),
              ),
            SliverToBoxAdapter(child: _settings(off)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Row(children: [
                  const Text('النسخ الاحتياطية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  _chip('${_list.length} / ${off.keep}'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: off.syncing ? null : () => _sync(backup: true),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('نسخة دلوقتي'),
                  ),
                ]),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())))
            else if (_list.isEmpty)
              SliverToBoxAdapter(
                child: _card(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Column(children: [
                      Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textMuted),
                      SizedBox(height: 8),
                      Text('مفيش نسخ لسه', style: TextStyle(color: AppColors.textMuted)),
                    ]),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: _list.length,
                itemBuilder: (_, i) => _backupTile(off, _list[i], i == 0),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, OfflineService off, DateTime? snap) {
    final ok = off.error == null && snap != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 16, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primaryLight], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(14)),
            child: off.syncing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Icon(ok ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('المزامنة والنسخ', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                off.syncing ? 'بنزّل كل البيانات من الكمبيوتر...' : (snap == null ? 'مفيش نسخة على الموبايل لسه' : 'البيانات لحد ${_dt(snap)}'),
                style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 12.5),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _stat('آخر مزامنة', _ago(off.lastSync)),
          _stat('حجم البيانات', _size(off.snapSize)),
          _stat('البرنامج', off.serverVersion == null || off.serverVersion!.isEmpty ? '—' : off.serverVersion!),
        ]),
        if (off.error != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(off.error!, style: const TextStyle(color: Colors.white, fontSize: 12.5))),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDark,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: off.syncing ? null : () => _sync(),
            icon: const Icon(Icons.sync_rounded),
            label: Text(off.syncing ? 'جاري المزامنة...' : 'مزامنة كاملة دلوقتي', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  Widget _stat(String l, String v) => Expanded(
        child: Container(
          margin: const EdgeInsetsDirectional.only(end: 8),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l, style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 11)),
            const SizedBox(height: 2),
            Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
          ]),
        ),
      );

  Widget _settings(OfflineService off) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('الإعدادات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: off.autoSync,
          onChanged: (v) => off.saveSettings(auto: v),
          title: const Text('مزامنة تلقائية'),
          subtitle: const Text('أول ما الموبايل يوصل للكمبيوتر، وكل 15 دقيقة وهو مفتوح'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: off.forceOffline,
          onChanged: (v) => off.reloadSystem(offline: v),
          title: const Text('اعرض النسخة المحفوظة دايماً'),
          subtitle: const Text('السيستم يفتح من الموبايل حتى لو الكمبيوتر متاح (أسرع، وللعرض بس)'),
        ),
        const Divider(height: 22),
        const Text('النسخ الاحتياطي التلقائي', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'daily', label: Text('مرة كل يوم'), icon: Icon(Icons.today, size: 18)),
              ButtonSegment(value: 'every', label: Text('كل مزامنة'), icon: Icon(Icons.sync, size: 18)),
              ButtonSegment(value: 'off', label: Text('مقفول'), icon: Icon(Icons.block, size: 18)),
            ],
            selected: {off.backupMode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => off.saveSettings(mode: s.first),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('عدد النسخ اللي تتحفظ')),
          DropdownButton<int>(
            value: [5, 10, 20, 30, 60].contains(off.keep) ? off.keep : 10,
            underline: const SizedBox(),
            items: const [5, 10, 20, 30, 60].map((n) => DropdownMenuItem(value: n, child: Text('آخر $n'))).toList(),
            onChanged: (n) async {
              if (n == null) return;
              await off.saveSettings(keepN: n);
              _refresh();
            },
          ),
        ]),
        const SizedBox(height: 4),
        const Text(
          'النسخة ملف .sqlite فيه كل بيانات الفيزا والكاش. تقدر تبعتها لنفسك (Drive / واتساب) وترجّعها على الكمبيوتر من الإعدادات ← استرجاع نسخة، والمستخدمين والباسوردات اللي على الكمبيوتر بيفضلوا زي ما هم.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
        ),
      ]),
    );
  }

  Widget _backupTile(OfflineService off, BackupFile b, bool latest) {
    return _card(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.storage_rounded, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(_dt(b.at), style: const TextStyle(fontWeight: FontWeight.w700))),
              if (latest) ...[const SizedBox(width: 6), _chip('الأحدث', color: AppColors.success)],
            ]),
            const SizedBox(height: 2),
            Text('${_size(b.size)} · ${_ago(b.at)}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ]),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (a) async {
            if (a == 'share') {
              await Share.shareXFiles([XFile(b.file.path, name: b.file.uri.pathSegments.last)], subject: 'نسخة رقابة الفيزا والكاش');
            } else if (a == 'view') {
              await off.openBackupAsOffline(b);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('افتح تبويب السيستم: بيعرض النسخة دي')));
              }
            } else if (a == 'del') {
              final yes = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('مسح النسخة؟'),
                  content: Text('النسخة بتاعة ${_dt(b.at)} هتتمسح من الموبايل.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('امسح'),
                    ),
                  ],
                ),
              );
              if (yes == true) {
                await off.deleteBackup(b);
                _refresh();
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'view', child: ListTile(leading: Icon(Icons.visibility_outlined), title: Text('اعرضها في السيستم'))),
            PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.ios_share), title: Text('ابعتها / احفظها برا'))),
            PopupMenuItem(value: 'del', child: ListTile(leading: Icon(Icons.delete_outline, color: AppColors.danger), title: Text('امسح'))),
          ],
        ),
      ]),
    );
  }

  Widget _chip(String t, {Color color = AppColors.primary}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      );

  Widget _card({required Widget child, EdgeInsets? margin, EdgeInsets? padding, Color? color}) => Container(
        margin: margin ?? const EdgeInsets.fromLTRB(14, 12, 14, 0),
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}
