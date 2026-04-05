import 'dart:typed_data';
import '../utils/modbus_crc.dart';

/// Modbus RTU 协议服务
class ModbusService {
  /// Function Code
  static const int READ_HOLDING_REGISTERS = 0x03;
  static const int WRITE_SINGLE_REGISTER = 0x06;
  static const int WRITE_MULTIPLE_REGISTERS = 0x10;

  /// RegisterAddress
  static const int REG_CURRENT = 0x00;
  static const int REG_PPR = 0x0001;
  static const int REG_STANDBY_CURRENT = 0x0003;
  static const int REG_ENABLE = 0x0006;
  static const int REG_CLEAR_ENABLE = 0x0007;
  static const int REG_ZERO = 0x0028;        // 零点PositionRegister
  static const int REG_DECEL_LOW = 0x003E;
  static const int REG_DECEL_HIGH = 0x003F;
  static const int REG_SPEED_LOW = 0x0040;
  static const int REG_SPEED_HIGH = 0x0041;
  static const int REG_ACCEL_LOW = 0x0042;
  static const int REG_ACCEL_HIGH = 0x0043;
  static const int REG_DISPLACEMENT_LOW = 0x0044;
  static const int REG_DISPLACEMENT_HIGH = 0x0045;
  static const int REG_CONTROL_MODE = 0x0046;   // Forward/Backward/StopRegisterAddress 0x0046
  static const int REG_QUERY_POSITION = 0x0027; // 查询PositionRegisterAddress 0x0027
  static const int REG_POSITION_MODE = 0x0048;
  static const int REG_SAVE_PARAMS = 0x005A;
  static const int REG_RESTORE_FACTORY = 0x005B;

  /// Control命令 - 使用0x0046Address的不同值
  static const int CMD_STOP = 0x0005;
  static const int CMD_FORWARD = 0x0004;
  static const int CMD_BACKWARD = 0x0003;
  static const int CMD_PAUSE = 0x0004;

  /// 构建ReadRegister命令
  String buildReadCommand(int deviceId, int register, int count) {
    String data = '${register.toRadixString(16).padLeft(4, '0').toUpperCase()}${count.toRadixString(16).padLeft(4, '0').toUpperCase()}';
    return ModbusCRC.buildFrame(deviceId, READ_HOLDING_REGISTERS, data);
  }

  /// 构建Write单个Register命令
  String buildWriteCommand(int deviceId, int register, int value) {
    String data = '${register.toRadixString(16).padLeft(4, '0').toUpperCase()}${value.toRadixString(16).padLeft(4, '0').toUpperCase()}';
    return ModbusCRC.buildFrame(deviceId, WRITE_SINGLE_REGISTER, data);
  }

  /// 构建Write32Bit值命令（使用两个Register）
  String buildWrite32Command(int deviceId, int registerLow, int value) {
    int low = value & 0xFFFF;
    int high = (value >> 16) & 0xFFFF;
    // 格式: RegisterAddress + 0002 + 04 + DataByte数(04) + Data(低16Bit + 高16Bit)
    String data = '${registerLow.toRadixString(16).padLeft(4, '0').toUpperCase()}000204${low.toRadixString(16).padLeft(4, '0').toUpperCase()}${high.toRadixString(16).padLeft(4, '0').toUpperCase()}';
    return ModbusCRC.buildFrame(deviceId, WRITE_MULTIPLE_REGISTERS, data);
  }

  /// 解析响应Data
  Map<String, dynamic>? parseResponse(Uint8List data) {
    if (data.length < 5) return null;
    
    int deviceId = data[0];
    int function = data[1];
    
    if (function == 0x03) {
      int byteCount = data[2];
      List<int> values = data.sublist(3, 3 + byteCount);
      return {
        'deviceId': deviceId,
        'function': function,
        'values': values,
      };
    }
    return null;
  }

  // ========== 电机Control命令构建 ==========

  /// 使能电机
  String enableMotor(int deviceId) => buildWriteCommand(deviceId, REG_ENABLE, 1);

  /// 禁用电机
  String disableMotor(int deviceId) => buildWriteCommand(deviceId, REG_ENABLE, 0);

  /// Stop (使用0x0046Address)
  String stop(int deviceId) => buildWriteCommand(deviceId, REG_CONTROL_MODE, CMD_STOP);

  /// 正转 (使用0x0046Address)
  String forward(int deviceId) => buildWriteCommand(deviceId, REG_CONTROL_MODE, CMD_FORWARD);

  /// 反转 (使用0x0046Address)
  String backward(int deviceId) => buildWriteCommand(deviceId, REG_CONTROL_MODE, CMD_BACKWARD);

  /// 归零 (Settings零点Position)
  String zero(int deviceId) => buildWriteCommand(deviceId, REG_ZERO, 1);

  /// SettingsSpeed
  String setSpeed(int deviceId, int speed) => buildWrite32Command(deviceId, REG_SPEED_LOW, speed);

  /// Settings加Speed
  String setAcceleration(int deviceId, int accel) => buildWrite32Command(deviceId, REG_ACCEL_LOW, accel);

  /// Settings减Speed
  String setDeceleration(int deviceId, int decel) => buildWrite32Command(deviceId, REG_DECEL_LOW, decel);

  /// SettingsDisplacement
  String setDisplacement(int deviceId, int displacement) {
    if (displacement < 0) {
      displacement = (1 << 32) + displacement;
    }
    return buildWrite32Command(deviceId, REG_DISPLACEMENT_LOW, displacement);
  }

  /// SettingsCurrent mA百分比
  String setCurrent(int deviceId, int percentage) => buildWriteCommand(deviceId, REG_STANDBY_CURRENT, percentage);

  /// SettingsPPR
  String setPPR(int deviceId, int ppr) => buildWriteCommand(deviceId, REG_PPR, ppr);

  /// Settings方向
  String setDirection(int deviceId, int direction) => buildWriteCommand(deviceId, REG_CONTROL_MODE, direction);

  // ========== Displacement模式 ==========
  
  /// SettingsDisplacement模式为绝对模式
  String setAbsMode(int deviceId) => buildWriteCommand(deviceId, REG_POSITION_MODE, 1);
  
  /// SettingsDisplacement模式为增量模式
  String setRelMode(int deviceId) => buildWriteCommand(deviceId, REG_POSITION_MODE, 2);
  
  /// 触发Displacement运动
  String triggerMove(int deviceId) => buildWriteCommand(deviceId, REG_CONTROL_MODE, 3);

  /// 保存Parameters
  String saveParams(int deviceId) => buildWriteCommand(deviceId, REG_SAVE_PARAMS, 1);

  /// 查询Speed
  String querySpeed(int deviceId) => buildReadCommand(deviceId, REG_SPEED_LOW, 2);

  /// 查询Displacement (使用0x0027Address)
  String queryDisplacement(int deviceId) => buildReadCommand(deviceId, REG_QUERY_POSITION, 2);

  /// 查询Current mA
  String queryCurrent(int deviceId) => buildReadCommand(deviceId, REG_CURRENT, 1);

  /// Hex命令转Byte列表
  List<int> hexToBytes(String hex) {
    hex = hex.replaceAll(' ', '');
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}