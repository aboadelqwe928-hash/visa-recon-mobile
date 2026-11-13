import 'package:flutter/foundation.dart';

/// طلب فتح شاشة معينة من السيستم (من الرئيسية أو التنبيهات).
/// HomeShell بيقلب على تبويب السيستم، و SystemScreen بيفتح الشاشة جوه الـ WebView.
class NavBus extends ChangeNotifier {
  String? view;
  String? day;
  int tick = 0;

  /// الشاشات: cash, combined, cashrep, final, search, whatsapp, data, dashboard ...
  void openSystem(String view, {String? day}) {
    this.view = view;
    this.day = day;
    tick++;
    notifyListeners();
  }
}
