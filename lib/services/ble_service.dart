/// 蓝牙BLE服务
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/connection_device.dart';
import '../utils/constants.dart';

class BLEService {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  final StreamController<List<ConnectionDevice>> _devicesController = StreamController<List<ConnectionDevice>>.broadcast();
  
  Stream<List<ConnectionDevice>> get devicesStream => _devicesController.stream;
  
  List<ConnectionDevice> _devices = [];

  /// 开始ScanDevice
  Future<void> startScan() async {
    _devices = [];
    
    // 检查蓝牙是否开启
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      await FlutterBluePlus.adapterState.firstWhere((s) => s == BluetoothAdapterState.on);
    }

    // 开始Scan
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      _devices = results
          .where((r) => r.device.platformName.isNotEmpty)
          .map((r) => ConnectionDevice(
                id: r.device.remoteId.str,
                name: r.device.platformName,
                connectionType: ConnectionType.ble,
                rssi: r.rssi,
              ))
          .toList();
      _devicesController.add(_devices);
    });
  }

  /// StopScan
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
  }

  /// Connect到Device
  Future<BluetoothDevice?> connect(String deviceId) async {
    try {
      final device = BluetoothDevice.fromId(deviceId);
      await device.connect(timeout: const Duration(seconds: 10));
      return device;
    } catch (e) {
      return null;
    }
  }

  /// 断开Connect
  Future<void> disconnect(BluetoothDevice device) async {
    await device.disconnect();
  }

  /// 发现服务和特征值
  Future<List<BluetoothService>> discoverServices(BluetoothDevice device) async {
    return await device.discoverServices();
  }

  /// SendData
  Future<void> writeData(BluetoothDevice device, String serviceUuid, String characteristicUuid, List<int> data) async {
    final services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid.str == serviceUuid) {
        for (var char in service.characteristics) {
          if (char.uuid.str == characteristicUuid) {
            await char.write(data, withoutResponse: false);
            return;
          }
        }
      }
    }
  }

  /// SendData到UART串口透传（使用标准UUID）
  Future<void> writeToUART(BluetoothDevice device, List<int> data) async {
    final services = await device.discoverServices();
    
    // 使用constants.dart中定义的UUID
    final String uartServiceUuid = AppConstants.bleServiceUUID.toLowerCase();
    final String uartWriteCharacteristicUuid = AppConstants.bleWriteCharacteristicUUID.toLowerCase();
    
    // 首先尝试Write特征值(FFE2)
    for (var service in services) {
      if (service.uuid.str.toLowerCase() == uartServiceUuid) {
        for (var char in service.characteristics) {
          if (char.uuid.str.toLowerCase() == uartWriteCharacteristicUuid && 
              char.properties.write) {
            await char.write(data, withoutResponse: false);
            return;
          }
        }
      }
    }
    
    // 如果没有找到UART特征值，尝试任何可写的特征值（兼容性）
    for (var service in services) {
      for (var char in service.characteristics) {
        if (char.properties.write) {
          await char.write(data, withoutResponse: false);
          return;
        }
      }
    }
    
    throw Exception('No writable characteristic found');
  }

  /// ReadData
  Future<List<int>> readData(BluetoothDevice device, String serviceUuid, String characteristicUuid) async {
    final services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid.str == serviceUuid) {
        for (var char in service.characteristics) {
          if (char.uuid.str == characteristicUuid) {
            return await char.read();
          }
        }
      }
    }
    return [];
  }

  void dispose() {
    _scanSubscription?.cancel();
    _devicesController.close();
  }
}