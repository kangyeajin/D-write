import 'package:flutter/material.dart';

import 'app_palette.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  AppPalette _palette = AppPalette.fog;

  ThemeMode get mode => _mode;
  AppPalette get palette => _palette;

  void setTheme(String theme) {
    final next = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    if (_mode == next) return;
    _mode = next;
    notifyListeners();
  }

  void setPalette(AppPalette palette) {
    if (_palette == palette) return;
    _palette = palette;
    notifyListeners();
  }

  void setPaletteById(String id) => setPalette(AppPaletteX.fromId(id));
}
