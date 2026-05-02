import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global toggle for Demo Mode vs Live Mode.
///
/// Demo Mode  → Uses hardcoded Persona data (Priya Sharma).
/// Live Mode  → Uses real data from scanned/uploaded records stored in SharedPreferences.
///
/// Access:  DataMode.isDemo.value (bool)
/// Toggle:  DataMode.toggle()
///
/// Hidden trigger: Triple-tap on the greeting text in HomeScreen.
class DataMode {
  
  DataMode._();

  static final ValueNotifier<bool> isDemo = ValueNotifier<bool>(true);

  static void toggle() {
    isDemo.value = !isDemo.value;
    _persist();
  }

  static void setDemo(bool value) {
    isDemo.value = value;
    _persist();
  }

  /// Load saved preference on app start.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isDemo.value = prefs.getBool('data_mode_demo') ?? true;
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('data_mode_demo', isDemo.value);
  }
}
