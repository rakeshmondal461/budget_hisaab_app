import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  String _currency = '₹';
  String _currencyCode = 'INR';
  bool _driveAutoSync = false;
  int _pomodoroMinutes = 25;
  int _shortBreakMinutes = 5;
  int _longBreakMinutes = 15;
  bool _notificationsEnabled = true;

  String get currency => _currency;
  String get currencyCode => _currencyCode;
  bool get driveAutoSync => _driveAutoSync;
  int get pomodoroMinutes => _pomodoroMinutes;
  int get shortBreakMinutes => _shortBreakMinutes;
  int get longBreakMinutes => _longBreakMinutes;
  bool get notificationsEnabled => _notificationsEnabled;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _currency = prefs.getString('currency') ?? '₹';
    _currencyCode = prefs.getString('currencyCode') ?? 'INR';
    _driveAutoSync = prefs.getBool('driveAutoSync') ?? false;
    _pomodoroMinutes = prefs.getInt('pomodoroMinutes') ?? 25;
    _shortBreakMinutes = prefs.getInt('shortBreakMinutes') ?? 5;
    _longBreakMinutes = prefs.getInt('longBreakMinutes') ?? 15;
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    notifyListeners();
  }

  Future<void> setCurrency(String symbol, String code) async {
    _currency = symbol;
    _currencyCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', symbol);
    await prefs.setString('currencyCode', code);
    notifyListeners();
  }

  Future<void> setDriveAutoSync(bool value) async {
    _driveAutoSync = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('driveAutoSync', value);
    notifyListeners();
  }

  Future<void> setPomodoroMinutes(int minutes) async {
    _pomodoroMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pomodoroMinutes', minutes);
    notifyListeners();
  }

  Future<void> setShortBreakMinutes(int minutes) async {
    _shortBreakMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('shortBreakMinutes', minutes);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
    notifyListeners();
  }

  static const List<Map<String, String>> currencies = [
    {'symbol': '₹', 'code': 'INR', 'name': 'Indian Rupee'},
    {'symbol': '\$', 'code': 'USD', 'name': 'US Dollar'},
    {'symbol': '€', 'code': 'EUR', 'name': 'Euro'},
    {'symbol': '£', 'code': 'GBP', 'name': 'British Pound'},
    {'symbol': '¥', 'code': 'JPY', 'name': 'Japanese Yen'},
    {'symbol': '﷼', 'code': 'SAR', 'name': 'Saudi Riyal'},
    {'symbol': 'د.إ', 'code': 'AED', 'name': 'UAE Dirham'},
  ];
}
