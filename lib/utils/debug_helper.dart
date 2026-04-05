import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// 蓝牙调试助手
class BluetoothDebugHelper {
  /// 打印蓝牙Device信息
  static void printDeviceInfo(String deviceName, String deviceId) {
    print('=== 蓝牙Device信息 ===');
    print('Device名称: $deviceName');
    print('DeviceID: $deviceId');
    print('Connect时间: ${DateTime.now()}');
    print('========================');
  }

  /// 打印服务信息
  static void printServiceInfo(List<BluetoothService> services) {
    print('=== 发现的服务 ===');
    print('服务数量: ${services.length}');
    
    for (var service in services) {
      print('服务UUID: ${service.uuid.str}');
      print('  特征值数量: ${service.characteristics.length}');
      
      for (var char in service.characteristics) {
        print('  特征值UUID: ${char.uuid.str}');
        print('    属性: ${_getProperties(char)}');
        print('    描述: ${char.descriptors.length}个描述符');
      }
    }
    print('========================');
  }

  /// 获取特征值属性
  static String _getProperties(BluetoothCharacteristic char) {
    List<String> props = [];
    if (char.properties.read) props.add('read');
    if (char.properties.write) props.add('write');
    if (char.properties.writeWithoutResponse) props.add('writeWithoutResponse');
    if (char.properties.notify) props.add('notify');
    if (char.properties.indicate) props.add('indicate');
    return props.join(', ');
  }

  /// 打印Send的Data
  static void printSendData(String hexCommand, List<int> bytes) {
    print('=== SendData（详细）===');
    print('原始指令: $hexCommand');
    print('Byte数组: $bytes');
    print('Hex: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}');
    print('Byte数: ${bytes.length}');
    
    // 分析Data格式
    if (bytes.isNotEmpty) {
      print('Data格式分析:');
      print('  第一个Byte: ${bytes[0]} (0x${bytes[0].toRadixString(16).toUpperCase()})');
      if (bytes.length > 1) {
        print('  第二个Byte: ${bytes[1]} (0x${bytes[1].toRadixString(16).toUpperCase()})');
      }
      
      // 检查是否是字符串格式（Error情况）
      bool mightBeString = bytes.every((b) => b >= 32 && b <= 126);
      if (mightBeString) {
        print('  ⚠️ 警告: Data看起来像ASCII字符串，不是Hex值！');
        print('  字符串内容: "${String.fromCharCodes(bytes)}"');
      } else {
        print('  ✅ Data格式正确（Hex值）');
      }
    }
    
    print('时间戳: ${DateTime.now().millisecondsSinceEpoch}');
    print('========================');
  }

  /// 打印Receive的Data
  static void printReceiveData(List<int> data) {
    if (data.isEmpty) return;
    
    print('=== ReceiveData ===');
    print('原始Byte: ${data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}');
    print('Byte数: ${data.length}');
    print('ASCII: ${String.fromCharCodes(data.where((b) => b >= 32 && b <= 126))}');
    print('时间戳: ${DateTime.now().millisecondsSinceEpoch}');
    print('========================');
  }

  /// 检查是否是标准UART服务
  static bool isUARTService(BluetoothService service) {
    String uuid = service.uuid.str.toLowerCase();
    return uuid.contains('ffe0') || 
           uuid.contains('6e400001') || // Nordic UART Service
           uuid.contains('0000ffe0');
  }

  /// 查找UART特征值
  static Map<String, BluetoothCharacteristic?> findUARTCharacteristics(BluetoothService service) {
    Map<String, BluetoothCharacteristic?> result = {
      'tx': null, // Send特征值
      'rx': null, // Receive特征值
    };
    
    for (var char in service.characteristics) {
      String uuid = char.uuid.str.toLowerCase();
      
      // 标准UART特征值
      if (uuid.contains('ffe2') || uuid.contains('6e400002')) {
        result['tx'] = char; // Send特征值
      } else if (uuid.contains('ffe1') || uuid.contains('6e400003')) {
        result['rx'] = char; // Receive特征值
      }
      
      // 如果没有标准特征值，尝试任何可写的特征值
      if (result['tx'] == null && char.properties.write) {
        result['tx'] = char;
      }
    }
    
    return result;
  }
}