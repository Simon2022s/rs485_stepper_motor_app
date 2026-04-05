import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/modbus_service.dart';
import '../services/storage_service.dart';
import '../utils/modbus_crc.dart';
import '../utils/constants.dart';

/// 电机状态管理 - 最终修复版
class MotorProvider extends ChangeNotifier {
  final ModbusService _modbus = ModbusService();
  final StorageService _storage = StorageService();
  
  // Notify监听器是否已Settings（避免重复注册）
  StreamSubscription<List<int>>? _notifySubscription;
  bool _notifyListenerSetup = false;
  
  BluetoothDevice? _bleDevice;
  BluetoothCharacteristic? _cachedWriteCharacteristic;
  BluetoothCharacteristic? _cachedNotifyCharacteristic;

  // 电机Parameters
  int _motorId = 1;
  int _speed = 1000;
  int _acceleration = 5000;
  int _deceleration = 5000;
  int _current = 50;
  int _ppr = 3200;
  int _displacement = 0;

  // Real-time Status
  int _realSpeed = 0;
  int _realPosition = 0;
  bool _isEnabled = false;
  bool _isRunning = false;
  int _direction = 0;
  String _lastQueryType = '';
  List<String> _logs = [];

  // Getters
  int get motorId => _motorId;
  int get speed => _speed;
  int get acceleration => _acceleration;
  int get deceleration => _deceleration;
  int get current => _current;
  int get currentmA => (_current * 20);
  int get ppr => _ppr;
  int get displacement => _displacement;
  int get realSpeed => _realSpeed;
  int get realPosition => _realPosition;
  bool get isEnabled => _isEnabled;
  bool get isRunning => _isRunning;
  int get direction => _direction;
  List<String> get logs => _logs;

  Future<void> init() async {
    await _storage.init();
    _motorId = _storage.getMotorId();
    _speed = _storage.getSpeed();
    _acceleration = _storage.getAcceleration();
    _deceleration = _storage.getDeceleration();
    _current = _storage.getCurrent();
    _ppr = _storage.getPpr();
    notifyListeners();
  }

  void setBLEDevice(BluetoothDevice? device) {
    _bleDevice = device;
  }
  
  void setCachedWriteCharacteristic(BluetoothCharacteristic? characteristic) {
    _cachedWriteCharacteristic = characteristic;
  }
  
  void setCachedNotifyCharacteristic(BluetoothCharacteristic? characteristic) {
    _cachedNotifyCharacteristic = characteristic;
  }

  void addLog(String log, {String? hexCommand}) {
    String timestamp = DateTime.now().toString().substring(11, 19);
    String logEntry = '[$timestamp] $log';
    if (hexCommand != null && hexCommand.isNotEmpty) {
      String formatted = _formatModbusFrame(hexCommand);
      if (log.isEmpty) {
        logEntry = '[$timestamp] $formatted';
      } else {
        logEntry += '\n    └─ $formatted';
      }
    }
    _logs.add(logEntry);
    if (_logs.length > 100) _logs.removeAt(0);
    notifyListeners();
  }

  String _formatModbusFrame(String hex) {
    StringBuffer sb = StringBuffer();
    for (int i = 0; i < hex.length; i += 2) {
      if (i > 0) sb.write(' ');
      if (i > 0 && i % 16 == 0) sb.write(' | ');
      sb.write(hex.substring(i, i + 2));
    }
    return sb.toString();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  Future<void> setupCachedNotifyListener() async {
    if (_cachedNotifyCharacteristic == null) return;
    try {
      if (!_cachedNotifyCharacteristic!.isNotifying) {
        await _cachedNotifyCharacteristic!.setNotifyValue(true);
      }
      _cachedNotifyCharacteristic!.onValueReceived.listen((value) {
        if (value.isNotEmpty) {
          String respHex = value.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
          addLog('RX', hexCommand: respHex);
          _parseModbusResponse(Uint8List.fromList(value));
        }
      });
    } catch (e) {
      print('SettingsNotify监听Failed: $e');
    }
  }

  void _parseModbusResponse(Uint8List data) {
    try {
      if (data.length < 5) return;
      int function = data[1];
      
      if (function == 0x03) {
        int byteCount = data[2];
        if (byteCount >= 4) {
          int low = (data[3] << 8) | data[4];
          int high = (data[5] << 8) | data[6];
          int value = (high << 16) | low;
          
          if (_lastQueryType == 'speed') {
            _realSpeed = value;
            // RPM = pulses/s * 60 / PPR
            int rpm = _ppr > 0 ? (_realSpeed * 60 ~/ _ppr) : 0;
            addLog('Speed response: $_realSpeed pulses/s ($rpm RPM)');
            notifyListeners();
            _lastQueryType = '';
          } else if (_lastQueryType == 'position') {
            _realPosition = value;
            addLog('Position response: $_realPosition pulses');
            notifyListeners();
            _lastQueryType = '';
          }
        }
      }
    } catch (e) {
      print('解析Modbus响应时出错: $e');
    }
  }

  /// SendModbus命令
  Future<void> _sendCommand(String hexCommand) async {
    if (_bleDevice == null) {
      addLog('', hexCommand: hexCommand);
      return;
    }
    
    // SendSuccess后才添加TXLogs（只添加一次，避免重复）
    bool sent = false;
    
    try {
      List<int> data = _modbus.hexToBytes(hexCommand);
      
      if (_cachedWriteCharacteristic != null && !sent) {
        try {
          await _cachedWriteCharacteristic!.write(data, withoutResponse: false);
          addLog('TX', hexCommand: hexCommand);
          sent = true;
          // SettingsNotify监听获取真实响应
          _tryReadResponse(hexCommand);
          return;
        } catch (e1) {
          try {
            await _cachedWriteCharacteristic!.write(data, withoutResponse: true);
            addLog('TX', hexCommand: hexCommand);
            sent = true;
            _tryReadResponse(hexCommand);
            return;
          } catch (e2) {
            print('缓存特征值WriteFailed');
          }
        }
      }
      
      // 重新发现服务并尝试多种UUID
      final services = await _bleDevice!.discoverServices();
      final String uartServiceUuid = AppConstants.bleServiceUUID.toLowerCase();
      final String uuid1 = AppConstants.bleWriteCharacteristicUUID.toLowerCase();
      final String uuid2 = AppConstants.bleWriteCharacteristicUUID_Alt.toLowerCase();
      
      print('查找服务: $uartServiceUuid');
      print('尝试UUID: $uuid1 或 $uuid2');
      print('发现服务数: ${services.length}');
      
      // 步骤1: 尝试查找匹配服务
      for (var service in services) {
        String serviceUuid = service.uuid.str.toLowerCase();
        print('服务: $serviceUuid, 特征值数: ${service.characteristics.length}');
        
        // 检查是否是目标服务（FFE0）
        if (serviceUuid == uartServiceUuid || serviceUuid.contains('ffe0')) {
          print('找到目标服务: $serviceUuid');
          
          // 步骤2: 首先尝试所有可写的特征值
          for (var char in service.characteristics) {
            if (char.properties.write || char.properties.writeWithoutResponse) {
              String charUuid = char.uuid.str.toLowerCase();
              print('尝试Write特征值: $charUuid, 属性: ${char.properties.write ? "Write" : "WriteWithoutResponse"}');
              
              _cachedWriteCharacteristic = char;
              _cachedNotifyCharacteristic = char;
              
              try {
                await char.write(data, withoutResponse: false);
                addLog('TX', hexCommand: hexCommand);
                print('✅ WriteSuccess（带响应）: $charUuid');
                await _tryReadResponse(hexCommand);
                return;
              } catch (e1) {
                try {
                  await char.write(data, withoutResponse: true);
                  addLog('TX', hexCommand: hexCommand);
                  print('✅ WriteSuccess（不带响应）: $charUuid');
                  await _tryReadResponse(hexCommand);
                  return;
                } catch (e2) {
                  print('特征值 $charUuid WriteFailed: $e2');
                }
              }
            }
          }
          
          // 步骤3: 如果没找到可写的，尝试所有特征值
          for (var char in service.characteristics) {
            String charUuid = char.uuid.str.toLowerCase();
            if (charUuid.contains('ffe1') || charUuid.contains('ffe2')) {
              print('尝试使用特征值: $charUuid (属性: Write=${char.properties.write}, Notify=${char.properties.notify})');
              
              _cachedWriteCharacteristic = char;
              _cachedNotifyCharacteristic = char;
              
              try {
                await char.write(data, withoutResponse: true);
                addLog('TX', hexCommand: hexCommand);
                print('✅ WriteSuccess: $charUuid');
                await _tryReadResponse(hexCommand);
                return;
              } catch (e) {
                print('特征值 $charUuid 尝试Failed: $e');
              }
            }
          }
          
          break;  // 只处理目标服务
        }
      }
      
      // 步骤4: 尝试所有服务中的所有可写特征值
      print('目标服务Not found，尝试所有服务...');
      for (var service in services) {
        for (var char in service.characteristics) {
          if (char.properties.write || char.properties.writeWithoutResponse) {
            String charUuid = char.uuid.str.toLowerCase();
            print('尝试Write特征值: $charUuid');
            
            _cachedWriteCharacteristic = char;
            _cachedNotifyCharacteristic = char;
            
            try {
              await char.write(data, withoutResponse: false);
              addLog('TX', hexCommand: hexCommand);
              print('✅ WriteSuccess: $charUuid');
              await _tryReadResponse(hexCommand);
              return;
            } catch (e1) {
              try {
                await char.write(data, withoutResponse: true);
                addLog('TX', hexCommand: hexCommand);
                print('✅ WriteSuccess: $charUuid');
                await _tryReadResponse(hexCommand);
                return;
              } catch (e2) {
                print('特征值 $charUuid WriteFailed');
              }
            }
          }
        }
      }
      
      addLog('Error: Not found可用的Write特征值');
    } catch (e) {
      print('Send命令时出错: $e');
      addLog('Error: $e');
    }
  }
  
  /// SettingsNotify监听来获取响应（只Settings一次，避免重复）
  Future<void> _tryReadResponse(String hexCommand) async {
    if (_cachedNotifyCharacteristic == null) return;
    
    // 如果支持Notify/Indicate，Settings监听获取真实响应
    if (_cachedNotifyCharacteristic!.properties.notify || 
        _cachedNotifyCharacteristic!.properties.indicate) {
      try {
        // 启用Notify
        if (!_cachedNotifyCharacteristic!.isNotifying) {
          await _cachedNotifyCharacteristic!.setNotifyValue(true);
        }
        
        // 只注册一次监听器，避免重复显示
        if (!_notifyListenerSetup) {
          _notifyListenerSetup = true;
          _cachedNotifyCharacteristic!.onValueReceived.listen((value) {
            if (value.isNotEmpty) {
              String respHex = value.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
              // 只显示真正的响应
              addLog('RX', hexCommand: respHex);
              _parseModbusResponse(Uint8List.fromList(value));
            }
          });
        }
      } catch (e) {
        print('Notify监听SettingsFailed: $e');
      }
    }
  }

  // ========== ParametersSettings ==========
  void setMotorId(int id) {
    _motorId = id;
    _storage.setMotorId(id);
    notifyListeners();
  }

  void setSpeed(int speed) {
    _speed = speed;
    _storage.setSpeed(speed);
    notifyListeners();
  }

  void setAcceleration(int accel) {
    _acceleration = accel;
    _storage.setAcceleration(accel);
    notifyListeners();
  }

  void setDeceleration(int decel) {
    _deceleration = decel;
    _storage.setDeceleration(decel);
    notifyListeners();
  }

  void setCurrent(int current) {
    _current = current;
    _storage.setCurrent(current);
    notifyListeners();
  }

  void setPpr(int ppr) {
    _ppr = ppr;
    _storage.setPpr(ppr);
    notifyListeners();
  }

  void setDisplacement(int displacement) {
    _displacement = displacement;
    notifyListeners();
  }

  // ========== 电机Control ==========
  Future<void> enable() async {
    String cmd = _modbus.enableMotor(_motorId);
    await _sendCommand(cmd);
    _isEnabled = true;
    addLog('Motor Enabled', hexCommand: cmd);
    notifyListeners();
  }

  Future<void> disable() async {
    String cmd = _modbus.disableMotor(_motorId);
    await _sendCommand(cmd);
    _isEnabled = false;
    addLog('Motor Disabled', hexCommand: cmd);
    notifyListeners();
  }

  Future<void> forward() async {
    String cmd = _modbus.forward(_motorId);
    await _sendCommand(cmd);
    _direction = 1;
    _isRunning = true;
    addLog('▶ Forward', hexCommand: cmd);
    notifyListeners();
  }

  Future<void> backward() async {
    String cmd = _modbus.backward(_motorId);
    await _sendCommand(cmd);
    _direction = 2;
    _isRunning = true;
    addLog('◀ Backward', hexCommand: cmd);
    notifyListeners();
  }

  Future<void> stop() async {
    String cmd = _modbus.stop(_motorId);
    await _sendCommand(cmd);
    _direction = 0;
    _isRunning = false;
    addLog('■ Stop', hexCommand: cmd);
    notifyListeners();
  }

  Future<void> zero() async {
    String cmd = _modbus.zero(_motorId);
    await _sendCommand(cmd);
    addLog('◎ Zero', hexCommand: cmd);
    notifyListeners();
  }

  Future<void> moveAbsolute() async {
    String cmd1 = _modbus.setAbsMode(_motorId);
    await _sendCommand(cmd1);
    addLog('Set Abs Mode', hexCommand: cmd1);
    await Future.delayed(const Duration(milliseconds: 50));
    String cmd2 = _modbus.setDisplacement(_motorId, _displacement);
    await _sendCommand(cmd2);
    addLog('Set Displacement: $_displacement', hexCommand: cmd2);
    // Trigger Move with value 0x0001 (changed from 0x0003)
    String cmd3 = ModbusCRC.buildFrame(_motorId, 0x06, '00460001');
    await _sendCommand(cmd3);
    addLog('Trigger Mov(Abs)', hexCommand: cmd3);
    notifyListeners();
  }

  Future<void> moveRelative() async {
    int relPos = _displacement.abs();
    // Set Rel Mode with value 0x0000 (changed from 0x0002)
    String cmd1 = ModbusCRC.buildFrame(_motorId, 0x06, '00480000');
    await _sendCommand(cmd1);
    addLog('Set Rel Mode', hexCommand: cmd1);
    await Future.delayed(const Duration(milliseconds: 50));
    String cmd2 = _modbus.setDisplacement(_motorId, relPos);
    await _sendCommand(cmd2);
    addLog('Set Displacement: $relPos', hexCommand: cmd2);
    // Trigger Move with value 0x0001 (changed from 0x0003)
    String cmd3 = ModbusCRC.buildFrame(_motorId, 0x06, '00460001');
    await _sendCommand(cmd3);
    addLog('Trigger Mov(Rel)', hexCommand: cmd3);
    notifyListeners();
  }

  // ========== Parameters下发 ==========
  Future<void> applySpeed() async {
    String cmd = _modbus.setSpeed(_motorId, _speed);
    await _sendCommand(cmd);
    addLog('Speed → $_speed', hexCommand: cmd);
  }

  Future<void> applyAcceleration() async {
    String cmd = _modbus.setAcceleration(_motorId, _acceleration);
    await _sendCommand(cmd);
    addLog('Acceleration set to $_acceleration', hexCommand: cmd);
  }

  Future<void> applyDeceleration() async {
    String cmd = _modbus.setDeceleration(_motorId, _deceleration);
    await _sendCommand(cmd);
    addLog('Deceleration set to $_deceleration', hexCommand: cmd);
  }

  Future<void> applyCurrent() async {
    String cmd = _modbus.setCurrent(_motorId, _current);
    await _sendCommand(cmd);
    addLog('Current set to $_current%', hexCommand: cmd);
  }

  Future<void> applyPPR() async {
    String cmd = _modbus.setPPR(_motorId, _ppr);
    await _sendCommand(cmd);
    addLog('PPR set to $_ppr', hexCommand: cmd);
  }

  /// Current mA: 01 06 00 00 [value_hex] CRC
  Future<void> applyCurrentMa(int currentMa) async {
    // 将值转换为4BitHex（大端序）
    String valueHex = currentMa.toRadixString(16).padLeft(4, '0').toUpperCase();
    String cmd = ModbusCRC.buildFrame(_motorId, 0x06, '0000$valueHex');
    await _sendCommand(cmd);
    addLog('Current mA set to $currentMa', hexCommand: cmd);
  }

  /// PPR: 01 06 00 01 [value_hex] CRC - 使用传入的值
  Future<void> applyPPRValue(int pprValue) async {
    // 将值转换为4BitHex（大端序）
    String valueHex = pprValue.toRadixString(16).padLeft(4, '0').toUpperCase();
    String cmd = ModbusCRC.buildFrame(_motorId, 0x06, '0001$valueHex');
    await _sendCommand(cmd);
    addLog('PPR set to $pprValue', hexCommand: cmd);
  }

  Future<void> applyDisplacement() async {
    String cmd = _modbus.setDisplacement(_motorId, _displacement);
    await _sendCommand(cmd);
    addLog('Displacement set to $_displacement', hexCommand: cmd);
  }

  Future<void> saveParams() async {
    String cmd = _modbus.saveParams(_motorId);
    await _sendCommand(cmd);
    addLog('Parameters saved', hexCommand: cmd);
  }

  // ========== Status Query ==========
  Future<void> querySpeed() async {
    _lastQueryType = 'speed';
    String cmd = _modbus.querySpeed(_motorId);
    await _sendCommand(cmd);
    addLog('Query Speed', hexCommand: cmd);
  }

  Future<void> queryPosition() async {
    _lastQueryType = 'position';
    String cmd = _modbus.queryDisplacement(_motorId);
    await _sendCommand(cmd);
    addLog('Query Position', hexCommand: cmd);
  }

  Future<void> queryCurrent() async {
    String cmd = _modbus.queryCurrent(_motorId);
    await _sendCommand(cmd);
    addLog('Query Current', hexCommand: cmd);
  }

  /// 手动Send指令
  Future<void> sendManualCommand(String hexCommand) async {
    if (hexCommand.isEmpty) {
      addLog('Error: Empty command');
      return;
    }
    
    try {
      String cleaned = hexCommand.replaceAll(' ', '').replaceAll(',', '');
      if (cleaned.length < 4) {
        addLog('Error: Command too short');
        return;
      }
      
      int deviceId = int.parse(cleaned.substring(0, 2), radix: 16);
      int function = int.parse(cleaned.substring(2, 4), radix: 16);
      String dataHex = cleaned.substring(4);
      String fullFrame = ModbusCRC.buildFrame(deviceId, function, dataHex);
      
      await _sendCommand(fullFrame);
      addLog('Manual Send', hexCommand: fullFrame);
    } catch (e) {
      addLog('Error: $e');
    }
  }
}