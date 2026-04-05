import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/connection_device.dart';
import '../services/ble_service.dart';
import '../services/sle_service.dart';
import '../utils/constants.dart';
import '../utils/debug_helper.dart';
import '../utils/serial_config.dart';

class ConnectionProvider extends ChangeNotifier {
  final BLEService _bleService = BLEService();
  final SLEService _sleService = SLEService();
  
  StreamSubscription<List<ScanResult>>? _bleScanSubscription;
  
  ConnectionType _connectionType = ConnectionType.ble;
  bool _isScanning = false;
  bool _isConnected = false;
  String? _connectedDeviceId;
  String? _connectedDeviceName;
  List<ConnectionDevice> _devices = [];
  
  // Serial Configuration状态
  bool _isConfiguringSerial = false;
  bool _serialConfigured = false;
  String _serialConfigStatus = 'Waiting for configuration';
  int _baudRate = SerialConfig.defaultBaudRate;  // 当前Baud Rate
  
  BluetoothDevice? _bleDevice;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  
  // 缓存蓝牙服务和特征值
  BluetoothService? _cachedUARTService;
  BluetoothCharacteristic? _cachedWriteCharacteristic;
  BluetoothCharacteristic? _cachedNotifyCharacteristic;

  ConnectionType get connectionType => _connectionType;
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  String? get connectedDeviceId => _connectedDeviceId;
  String? get connectedDeviceName => _connectedDeviceName;
  List<ConnectionDevice> get devices => _devices;
  
  // Serial Configuration状态getters
  bool get isConfiguringSerial => _isConfiguringSerial;
  bool get serialConfigured => _serialConfigured;
  String get serialConfigStatus => _serialConfigStatus;
  int get baudRate => _baudRate;
  
  // 缓存特征值getters
  BluetoothDevice? get bleDevice => _bleDevice;
  BluetoothCharacteristic? get cachedWriteCharacteristic => _cachedWriteCharacteristic;
  BluetoothCharacteristic? get cachedNotifyCharacteristic => _cachedNotifyCharacteristic;

  void demoConnect() {
    _isConnected = true;
    _connectedDeviceId = '00:11:22:33:44:55';
    _connectedDeviceName = 'DTU-001 (Demo)';
    notifyListeners();
  }

  void setConnectionType(ConnectionType type) {
    _connectionType = type;
    notifyListeners();
  }

  /// SettingsBaud Rate
  void setBaudRate(int baudRate) {
    if (SerialConfig.supportedBaudRates.contains(baudRate)) {
      _baudRate = baudRate;
      notifyListeners();
    }
  }

  Future<void> startScan() async {
    if (_isScanning) return;
    _isScanning = true;
    _devices = [];
    notifyListeners();

    try {
      if (_connectionType == ConnectionType.ble) {
        // Request permissions
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();
        
        // Check if Bluetooth is on
        if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
          await FlutterBluePlus.adapterState.firstWhere((s) => s == BluetoothAdapterState.on);
        }
        
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
        
        _bleScanSubscription = FlutterBluePlus.scanResults.listen((results) {
          _devices = results
              .where((r) => r.device.platformName.isNotEmpty)
              .map((r) => ConnectionDevice(
                    id: r.device.remoteId.str,
                    name: r.device.platformName,
                    connectionType: ConnectionType.ble,
                    rssi: r.rssi,
                  ))
              .toList();
          notifyListeners();
        });
      } else {
        await _sleService.startScan();
      }
    } catch (e) {
      // If scan fails (no Bluetooth or permission denied), show demo devices
      _devices = [
        ConnectionDevice(
          id: '00:11:22:33:44:55',
          name: 'DTU-001 (Demo)',
          connectionType: _connectionType,
          rssi: -50,
        ),
        ConnectionDevice(
          id: 'AA:BB:CC:DD:EE:FF',
          name: 'RS485-DTU (Demo)',
          connectionType: _connectionType,
          rssi: -60,
        ),
      ];
      notifyListeners();
    }
    
    _isScanning = false;
    notifyListeners();
  }

  Future<void> stopScan() async {
    if (_connectionType == ConnectionType.ble) {
      await FlutterBluePlus.stopScan();
      await _bleScanSubscription?.cancel();
    } else {
      await _sleService.stopScan();
    }
    _isScanning = false;
    notifyListeners();
  }

  Future<bool> connect(ConnectionDevice device) async {
    try {
      if (device.connectionType == ConnectionType.ble) {
        print('=== 开始蓝牙Connect ===');
        print('DeviceID: ${device.id}');
        print('Device名称: ${device.name}');
        
        _bleDevice = BluetoothDevice.fromId(device.id);
        print('创建蓝牙Device对象Success');
        
        await _bleDevice!.connect(timeout: const Duration(seconds: 10));
        print('✅ 蓝牙ConnectSuccess');
        
        // 调试：打印Device信息
        BluetoothDebugHelper.printDeviceInfo(device.name, device.id);
        
        // 完整的DTU Configuration序列
        print('Starting complete DTU configuration...');
        _isConfiguringSerial = true;
        _serialConfigStatus = 'Configuring DTU...';
        notifyListeners();
        
        // Wait所有AT命令Send完成（使用选定的Baud Rate）
        bool dtuConfigured = await SerialConfig.configureSerial(_bleDevice!, baudRate: _baudRate);
        
        _isConfiguringSerial = false;
        _serialConfigured = dtuConfigured;
        
        if (dtuConfigured) {
          print('✅ DTU fully configured and ready for Modbus communication');
          _serialConfigStatus = '✅ DTU ready ($_baudRate 8N1 HEX)';
          
          // 缓存服务和特征值
          await _cacheBluetoothCharacteristics();
          
          // Send测试命令验证Connect
          await _sendTestCommand();
        } else {
          print('⚠️ DTU configuration incomplete, app will use demo mode');
          _serialConfigStatus = '⚠️ DTU config incomplete, using demo mode';
        }
        notifyListeners();
        
        _connectionSubscription = _bleDevice!.connectionState.listen((state) {
          print('蓝牙Connect状态变化: $state');
          if (state == BluetoothConnectionState.disconnected) {
            _isConnected = false;
            _connectedDeviceId = null;
            _connectedDeviceName = null;
            notifyListeners();
          }
        });
        
        _isConnected = true;
        _connectedDeviceId = device.id;
        _connectedDeviceName = device.name;
        notifyListeners();
        
        print('=== 蓝牙Connect完成 ===');
        return true;
      } else {
        int? handle = await _sleService.connect(device.id);
        if (handle != null && handle > 0) {
          _isConnected = true;
          _connectedDeviceId = device.id;
          _connectedDeviceName = device.name;
          notifyListeners();
          return true;
        }
        return false;
      }
    } catch (e) {
      print('❌ 蓝牙ConnectFailed: $e');
      // Connection failed, use demo mode
      _isConnected = true;
      _connectedDeviceId = device.id;
      _connectedDeviceName = device.name + ' (Demo)';
      notifyListeners();
      return true;
    }
  }

  Future<void> disconnect() async {
    if (_connectionType == ConnectionType.ble && _bleDevice != null) {
      await _bleDevice!.disconnect();
      await _connectionSubscription?.cancel();
    }
    _isConnected = false;
    _connectedDeviceId = null;
    _connectedDeviceName = null;
    
    // 重置Serial Configuration状态
    _isConfiguringSerial = false;
    _serialConfigured = false;
    _serialConfigStatus = 'Waiting for configuration';
    _baudRate = SerialConfig.defaultBaudRate;  // 重置为默认Baud Rate
    
    // Clear缓存
    _cachedUARTService = null;
    _cachedWriteCharacteristic = null;
    _cachedNotifyCharacteristic = null;
    
    notifyListeners();
  }

  /// 缓存蓝牙服务和特征值
  Future<void> _cacheBluetoothCharacteristics() async {
    try {
      print('=== 开始缓存蓝牙特征值 ===');
      
      if (_bleDevice == null) {
        print('❌ 没有蓝牙Device，无法缓存特征值');
        return;
      }
      
      final services = await _bleDevice!.discoverServices();
      print('发现服务数量: ${services.length}');
      
      // 使用constants.dart中定义的UUID
      final String uartServiceUuid = AppConstants.bleServiceUUID.toLowerCase();
      final String uartWriteCharacteristicUuid = AppConstants.bleWriteCharacteristicUUID.toLowerCase();
      final String uartNotifyCharacteristicUuid = AppConstants.bleNotifyCharacteristicUUID.toLowerCase();
      
      print('目标服务UUID: $uartServiceUuid');
      print('目标Write特征值UUID: $uartWriteCharacteristicUuid');
      print('目标Notify特征值UUID: $uartNotifyCharacteristicUuid');
      
      for (var service in services) {
        if (service.uuid.str.toLowerCase() == uartServiceUuid) {
          print('✅ 找到UART服务: ${service.uuid.str}');
          _cachedUARTService = service;
          
          for (var char in service.characteristics) {
            String charUuid = char.uuid.str.toLowerCase();
            print('  特征值: $charUuid, 属性: ${_getCharacteristicProperties(char)}');
            
            if (charUuid == uartWriteCharacteristicUuid && char.properties.write) {
              print('  ✅ 找到Write特征值: $charUuid');
              _cachedWriteCharacteristic = char;
            }
            
            if (charUuid == uartNotifyCharacteristicUuid && char.properties.notify) {
              print('  ✅ 找到Notify特征值: $charUuid');
              _cachedNotifyCharacteristic = char;
              
              // 立即SettingsNotify监听
              try {
                await char.setNotifyValue(true);
                print('  ✅ Notify监听已Settings');
                
                // Settings一个简单的监听，只打印Data用于调试
                char.onValueReceived.listen((value) {
                  if (value.isNotEmpty) {
                    String respHex = value.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
                    print('📥 [ConnectionProvider] 收到NotifyData: $respHex');
                    print('📥 Data长度: ${value.length}Byte');
                    print('📥 原始Data: $value');
                    
                    // 这里应该将Data传递给MotorProvider，但需要上下文
                    // 暂时只打印调试信息
                  }
                });
              } catch (e) {
                print('  ❌ SettingsNotify监听Failed: $e');
              }
            }
          }
          break;
        }
      }
      
      if (_cachedWriteCharacteristic != null) {
        print('✅ Write特征值缓存Success');
      } else {
        print('❌ Not foundWrite特征值');
      }
      
      if (_cachedNotifyCharacteristic != null) {
        print('✅ Notify特征值缓存Success');
      } else {
        print('❌ Not foundNotify特征值');
      }
      
      print('=== 蓝牙特征值缓存完成 ===');
    } catch (e) {
      print('❌ 缓存蓝牙特征值时出错: $e');
    }
  }
  
  /// Send测试命令验证Connect
  Future<void> _sendTestCommand() async {
    try {
      if (_cachedWriteCharacteristic == null) {
        print('❌ 没有缓存的Write特征值，无法Send测试命令');
        return;
      }
      
      print('=== Send测试命令验证Connect和Notify监听 ===');
      
      // Wait一小段时间，确保Notify监听已Settings
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 简单的Modbus查询命令：查询DeviceID 1的Speed
      // 命令: 01 03 00 40 00 02 C5 CB
      List<int> testCommand = [0x01, 0x03, 0x00, 0x40, 0x00, 0x02, 0xC5, 0xCB];
      
      print('测试命令: ${_bytesToHex(testCommand)}');
      print('命令Note: 查询DeviceID 1的SpeedRegister (0x0040-0x0041)');
      print('预期响应: 01 03 04 XX XX XX XX CRC (4ByteData)');
      print('注意: 此测试用于验证Notify监听是否工作');
      
      try {
        // 尝试带响应Write
        await _cachedWriteCharacteristic!.write(testCommand, withoutResponse: false);
        print('✅ 测试命令SendSuccess（带响应）');
        _serialConfigStatus = '✅ DTU ready - Test query sent';
        
        // Wait响应
        print('Wait响应...（3sTimeout）');
        await Future.delayed(const Duration(seconds: 3));
        
      } catch (e) {
        print('❌ 带响应WriteFailed: $e');
        
        try {
          // 尝试不带响应Write
          await _cachedWriteCharacteristic!.write(testCommand, withoutResponse: true);
          print('✅ 测试命令SendSuccess（不带响应）');
          _serialConfigStatus = '✅ DTU ready - Test query sent (no response)';
          
          // Wait响应
          print('Wait响应...（3sTimeout）');
          await Future.delayed(const Duration(seconds: 3));
          
        } catch (e2) {
          print('❌ 不带响应WriteFailed: $e2');
          _serialConfigStatus = '⚠️ DTU ready - Test query failed';
        }
      }
      
      print('=== 测试命令Send完成 ===');
      print('请检查Logs中是否有"RX"开头的返回Data');
      notifyListeners();
    } catch (e) {
      print('❌ Send测试命令时出错: $e');
    }
  }
  
  /// Byte数组转Hex字符串
  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  /// 获取特征值属性字符串
  String _getCharacteristicProperties(BluetoothCharacteristic char) {
    List<String> props = [];
    if (char.properties.read) props.add('read');
    if (char.properties.write) props.add('write');
    if (char.properties.writeWithoutResponse) props.add('writeWithoutResponse');
    if (char.properties.notify) props.add('notify');
    if (char.properties.indicate) props.add('indicate');
    return props.join(', ');
  }

  @override
  void dispose() {
    _bleScanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _bleService.dispose();
    _sleService.dispose();
    super.dispose();
  }
}