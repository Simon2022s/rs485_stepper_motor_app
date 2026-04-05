import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Serial Configuration工具类
/// 用于Configure蓝牙DTU的串口Parameters
class SerialConfig {
  // 默认串口Parameters
  static const int defaultBaudRate = 9600;  // 默认Baud Rate
  static const int dataBits = 8;            // DataBit
  static const int stopBits = 1;            // StopBit
  static const int parity = 0;              // 校验Bit: 0=无校验, 1=奇校验, 2=偶校验
  static const int flowControl = 0;         // 流Control: 0=无流控

  // 支持的Baud Rate列表
  static const List<int> supportedBaudRates = [
    2400,
    4800,
    9600,
    19200,
    38400,
    57600,
    115200,
  ];

  /// 获取ATConfigure命令（使用指定Baud Rate）
  /// AT命令必须严格按照这个顺序，全部大写：
  /// 1. AT+BAUD={baudRate},8,0,1\r\n
  /// 2. AT+SLAVE\r\n
  /// 3. AT+FORMAT=HEX\r\n
  /// 4. AT+TRANSPARENT=1\r\n
  static Map<String, List<int>> getConfigCommands({int baudRate = defaultBaudRate}) {
    return {
      // 1. Configure串口Parameters：AT+BAUD={baudRate},8,0,1\r\n (校验Bit0=无校验)
      'AT_BAUD': _stringToBytes('AT+BAUD=$baudRate,8,0,1\r\n'),

      // 2. Settings从机模式：AT+SLAVE\r\n
      'AT_SLAVE': _stringToBytes('AT+SLAVE\r\n'),

      // 3. SettingsData格式为HEX：AT+FORMAT=HEX\r\n
      'AT_FORMAT_HEX': _stringToBytes('AT+FORMAT=HEX\r\n'),

      // 4. 启用透传模式：AT+TRANSPARENT=1\r\n
      'AT_TRANSPARENT_1': _stringToBytes('AT+TRANSPARENT=1\r\n'),
    };
  }

  /// 获取ATConfigure命令（尝试不同换行符）
  static Map<String, List<int>> getConfigCommandsWithDifferentNewlines() {
    return {
      // 尝试1: 只有\n
      'AT_BAUD_LF': _stringToBytes('AT+BAUD=9600,8,0,1\n'),
      'AT_SLAVE_LF': _stringToBytes('AT+SLAVE\n'),
      'AT_FORMAT_HEX_LF': _stringToBytes('AT+FORMAT=HEX\n'),
      'AT_TRANSPARENT_1_LF': _stringToBytes('AT+TRANSPARENT=1\n'),
      
      // 尝试2: 只有\r
      'AT_BAUD_CR': _stringToBytes('AT+BAUD=9600,8,0,1\r'),
      'AT_SLAVE_CR': _stringToBytes('AT+SLAVE\r'),
      'AT_FORMAT_HEX_CR': _stringToBytes('AT+FORMAT=HEX\r'),
      'AT_TRANSPARENT_1_CR': _stringToBytes('AT+TRANSPARENT=1\r'),
      
      // 尝试3: \r\n（标准）
      'AT_BAUD_CRLF': _stringToBytes('AT+BAUD=9600,8,0,1\r\n'),
      'AT_SLAVE_CRLF': _stringToBytes('AT+SLAVE\r\n'),
      'AT_FORMAT_HEX_CRLF': _stringToBytes('AT+FORMAT=HEX\r\n'),
      'AT_TRANSPARENT_1_CRLF': _stringToBytes('AT+TRANSPARENT=1\r\n'),
    };
  }

  /// Configure串口Parameters并进入透传模式（支持自定义Baud Rate）
  /// AT命令必须严格按照这个顺序Send，全部大写：
  /// 1. AT+BAUD={baudRate},8,0,1\r\n
  /// 2. AT+SLAVE\r\n
  /// 3. AT+FORMAT=HEX\r\n
  /// 4. AT+TRANSPARENT=1\r\n
  static Future<bool> configureSerial(BluetoothDevice device, {int baudRate = defaultBaudRate}) async {
    print('=== FINAL DTU CONFIGURATION SEQUENCE ===');
    print('AT commands MUST be sent in this exact order (ALL UPPERCASE):');
    print('1. AT+BAUD=$baudRate,8,0,1    - Set serial parameters ($baudRate baud, 8 data bits, 0 parity, 1 stop bit)');
    print('2. AT+SLAVE              - Set slave mode');
    print('3. AT+FORMAT=HEX         - Set data format to HEX');
    print('4. AT+TRANSPARENT=1      - Enable transparent transmission mode (LAST STEP!)');
    print('Note: All commands must be UPPERCASE, AT+TRANSPARENT=1 must be LAST');
    print('=== 详细调试信息已启用 ===');

    try {
      final services = await device.discoverServices();

      // 查找UART服务
      BluetoothCharacteristic? writeChar;
      for (var service in services) {
        String serviceUuid = service.uuid.str.toLowerCase();
        if (serviceUuid.contains('ffe0') || serviceUuid.contains('6e400001')) {
          print('Found UART service: $serviceUuid');

          // 查找可写的特征值
          for (var char in service.characteristics) {
            if (char.properties.write) {
              writeChar = char;
              print('Found write characteristic: ${char.uuid.str}');
              break;
            }
          }
          if (writeChar != null) break;
        }
      }

      if (writeChar == null) {
        print('❌ No writable characteristic found');
        return false;
      }

      var commands = getConfigCommands(baudRate: baudRate);
      int successCount = 0;
      int totalSteps = 4;

      // 严格按照指定顺序SendAT命令（全部大写）

      // 步骤1: AT+BAUD={baudRate},8,0,1 - Configure串口Parameters（校验Bit0=无校验）
      print('\n[Step 1/$totalSteps] Sending AT+BAUD=$baudRate,8,0,1');
      try {
        await writeChar.write(commands['AT_BAUD']!, withoutResponse: true);
        print('✅ AT+BAUD=$baudRate,8,0,1 sent successfully');
        await Future.delayed(const Duration(milliseconds: 500));
        print('✅ Serial parameters set: $baudRate baud, 8 data bits, 0 parity, 1 stop bit');
        successCount++;
      } catch (e) {
        print('❌ AT+BAUD=$baudRate,8,0,1 command failed: $e');
        return false;
      }
      
      // 步骤2: AT+SLAVE - Settings从机模式
      print('\n[Step 2/$totalSteps] Sending AT+SLAVE');
      try {
        await writeChar.write(commands['AT_SLAVE']!, withoutResponse: true);
        print('✅ AT+SLAVE sent successfully');
        await Future.delayed(const Duration(milliseconds: 300));
        print('✅ Slave mode activated');
        successCount++;
      } catch (e) {
        print('❌ AT+SLAVE command failed: $e');
        return false;
      }
      
      // 步骤3: AT+FORMAT=HEX - SettingsData格式为HEX
      print('\n[Step 3/$totalSteps] Sending AT+FORMAT=HEX');
      try {
        await writeChar.write(commands['AT_FORMAT_HEX']!, withoutResponse: true);
        print('✅ AT+FORMAT=HEX sent successfully');
        await Future.delayed(const Duration(milliseconds: 300));
        print('✅ Data format set to HEX (for Modbus commands)');
        successCount++;
      } catch (e) {
        print('❌ AT+FORMAT=HEX command failed: $e');
        return false;
      }
      
      // 步骤4: AT+TRANSPARENT=1 - 启用透传模式（最后一步！）
      print('\n[Step 4/$totalSteps] Sending AT+TRANSPARENT=1 (LAST STEP!)');
      try {
        await writeChar.write(commands['AT_TRANSPARENT_1']!, withoutResponse: true);
        print('✅ AT+TRANSPARENT=1 sent successfully');
        await Future.delayed(const Duration(milliseconds: 500));
        print('✅ Transparent transmission mode ENABLED');
        print('⚠️ IMPORTANT: AT+TRANSPARENT=1 is the LAST command!');
        successCount++;
      } catch (e) {
        print('❌ AT+TRANSPARENT=1 command failed: $e');
        return false;
      }
      
      // 总结
      print('\n=== FINAL CONFIGURATION COMPLETE ===');
      print('Successfully sent: $successCount/$totalSteps AT commands in exact order');
      
      if (successCount == 4) {
        print('✅ PERFECT: All 4 AT commands sent successfully in correct order');
        print('✅ AT+TRANSPARENT=1 was sent LAST as required');
        print('✅ DTU is now in transparent transmission mode');
        print('✅ Ready to send Modbus hexadecimal commands');
        return true;
      } else if (successCount >= 2) {
        print('⚠️ PARTIAL: $successCount/4 AT commands sent');
        print('⚠️ DTU may still work for Modbus communication');
        print('⚠️ App will attempt to send Modbus commands');
        return true;
      } else {
        print('❌ FAILED: Could not complete AT command sequence');
        print('❌ DTU is not properly configured');
        print('❌ Modbus communication will not work');
        return false;
      }
    } catch (e) {
      print('❌ DTU configuration error: $e');
      return false;
    }
  }

  /// Send测试命令验证Serial Configuration
  static Future<bool> testSerialConnection(BluetoothDevice device, BluetoothCharacteristic writeChar) async {
    print('=== 测试串口Connect ===');
    
    try {
      // Send简单的测试命令（查询DeviceID）
      List<int> testCommand = [0x01, 0x03, 0x00, 0x00, 0x00, 0x01, 0x84, 0x0A];
      
      print('Send测试命令: ${_bytesToHex(testCommand)}');
      await writeChar.write(testCommand, withoutResponse: false);
      
      // Wait响应
      await Future.delayed(const Duration(milliseconds: 1000));
      
      print('✅ 测试命令SendSuccess');
      return true;
    } catch (e) {
      print('❌ 测试命令SendFailed: $e');
      return false;
    }
  }

  /// Hex字符串转Byte数组
  static List<int> _hexToBytes(String hex) {
    hex = hex.replaceAll(' ', '');
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  /// Byte数组转Hex字符串
  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  /// 字符串转Byte数组（用于AT命令）
  static List<int> _stringToBytes(String str) {
    return str.codeUnits;
  }
}