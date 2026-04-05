import '../utils/constants.dart';

/// ConnectDeviceData模型
class ConnectionDevice {
  final String id;
  final String name;
  final String? macAddress;
  final int? rssi;
  final ConnectionType connectionType;
  bool isConnected;

  ConnectionDevice({
    required this.id,
    required this.name,
    this.macAddress,
    this.rssi,
    required this.connectionType,
    this.isConnected = false,
  });

  /// 从蓝牙Device创建
  factory ConnectionDevice.fromBluetooth({
    required String id,
    required String name,
    String? macAddress,
    int? rssi,
  }) {
    return ConnectionDevice(
      id: id,
      name: name,
      macAddress: macAddress,
      rssi: rssi,
      connectionType: ConnectionType.ble,
    );
  }

  /// 从星闪Device创建
  factory ConnectionDevice.fromSLE({
    required String id,
    required String name,
    String? macAddress,
    int? rssi,
  }) {
    return ConnectionDevice(
      id: id,
      name: name,
      macAddress: macAddress,
      rssi: rssi,
      connectionType: ConnectionType.sle,
    );
  }

  /// 获取信号强度描述
  String get signalStrength {
    if (rssi == null) return '未知';
    if (rssi! >= -50) return '强';
    if (rssi! >= -70) return '中';
    return '弱';
  }

  /// 获取Connect类型描述
  String get connectionTypeName {
    switch (connectionType) {
      case ConnectionType.ble:
        return '蓝牙BLE';
      case ConnectionType.sle:
        return '星闪SLE';
    }
  }

  @override
  String toString() {
    return 'ConnectionDevice(name: $name, id: $id, type: $connectionTypeName, '
        'rssi: $rssi dBm, connected: $isConnected)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionDevice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}