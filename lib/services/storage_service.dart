import 'package:shared_preferences/shared_preferences.dart';

/// 本地存储服务
class StorageService {
  static const String _keyMotorId = 'motor_id';
  static const String _keySpeed = 'speed';
  static const String _keyAcceleration = 'acceleration';
  static const String _keyDeceleration = 'deceleration';
  static const String _keyCurrent = 'current';
  static const String _keyPpr = 'ppr';
  static const String _keyLastDevice = 'last_device';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Motor ID
  int getMotorId() => _prefs.getInt(_keyMotorId) ?? 1;
  Future<void> setMotorId(int id) => _prefs.setInt(_keyMotorId, id);

  // Speed
  int getSpeed() => _prefs.getInt(_keySpeed) ?? 1000;
  Future<void> setSpeed(int speed) => _prefs.setInt(_keySpeed, speed);

  // 加Speed
  int getAcceleration() => _prefs.getInt(_keyAcceleration) ?? 5000;
  Future<void> setAcceleration(int accel) => _prefs.setInt(_keyAcceleration, accel);

  // 减Speed
  int getDeceleration() => _prefs.getInt(_keyDeceleration) ?? 5000;
  Future<void> setDeceleration(int decel) => _prefs.setInt(_keyDeceleration, decel);

  // Current mA
  int getCurrent() => _prefs.getInt(_keyCurrent) ?? 50;
  Future<void> setCurrent(int current) => _prefs.setInt(_keyCurrent, current);

  // PPR
  int getPpr() => _prefs.getInt(_keyPpr) ?? 2000;
  Future<void> setPpr(int ppr) => _prefs.setInt(_keyPpr, ppr);

  // 上次Connect的Device
  String? getLastDevice() => _prefs.getString(_keyLastDevice);
  Future<void> setLastDevice(String deviceId) => _prefs.setString(_keyLastDevice, deviceId);
}