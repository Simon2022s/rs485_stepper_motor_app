/// Modbus Function Code
class ModbusFunction {
  static const int readHoldingRegisters = 0x03;
  static const int writeSingleRegister = 0x06;
  static const int writeMultipleRegisters = 0x10;
}

/// Modbus RegisterAddress
class ModbusRegister {
  // Current mA相关
  static const int current = 0x0000;
  static const int standbyCurrent = 0x0003;
  static const int peakCurrent = 0x001A;
  
  // Speed和加Speed
  static const int speedLow = 0x0040;
  static const int speedHigh = 0x0041;
  static const int accelLow = 0x0042;
  static const int accelHigh = 0x0043;
  static const int decelLow = 0x003E;
  static const int decelHigh = 0x003F;
  
  // Displacement
  static const int displacementLow = 0x0044;
  static const int displacementHigh = 0x0045;
  static const int pulseCounterLow = 0x0027;
  static const int pulseCounterHigh = 0x0028;
  
  // Control
  static const int enable = 0x0006;
  static const int clearEnable = 0x0007;
  static const int controlMode = 0x0046;
  static const int positionMode = 0x0048;
  
  // 系统
  static const int saveParams = 0x005A;
  static const int restoreFactory = 0x005B;
  static const int direction = 0x0033;
  static const int ppr = 0x0001;
}

/// 电机Control命令
class MotorCommand {
  static const int stop = 0x0000;
  static const int forward = 0x0001;
  static const int backward = 0x0002;
  static const int pause = 0x0004;
}

/// Apply常量
class AppConstants {
  // ConnectTimeout时间（ms）
  static const int connectionTimeout = 10000;
  
  // 读写Timeout时间（ms）
  static const int readTimeout = 5000;
  static const int writeTimeout = 5000;
  
  // 蓝牙服务UUID - SPP_BLE使用的标准蓝牙串口透传UUID (FFE0)
  static const String bleServiceUUID = '0000FFE0-0000-1000-8000-00805F9B34FB';
  
  // 蓝牙特征值UUID - 支持多种Configure
  // Configure1: SPP_BLE默认 (FFE1用于RX和TX)
  static const String bleNotifyCharacteristicUUID = '0000FFE1-0000-1000-8000-00805F9B34FB';  // RXI (通知)
  static const String bleWriteCharacteristicUUID = '0000FFE1-0000-1000-8000-00805F9B34FB';   // TXO (Write)
  
  // 备用特征值UUID (FFE2 - 有些DTU使用这个作为Write)
  static const String bleWriteCharacteristicUUID_Alt = '0000FFE2-0000-1000-8000-00805F9B34FB';
  
  // Motor IDRange
  static const int minMotorId = 1;
  static const int maxMotorId = 255;
  
  // SpeedRange
  static const int minSpeed = 0;
  static const int maxSpeed = 65535;
  
  // 加减SpeedRange
  static const int minAccel = 0;
  static const int maxAccel = 2147483647;
  
  // Current mA百分比Range
  static const int minCurrent = 0;
  static const int maxCurrent = 100;
  
  // PPRRange
  static const int minPPR = 1;
  static const int maxPPR = 65535;
  
  // Logs最大条数
  static const int maxLogEntries = 500;
}

/// Connect类型
enum ConnectionType {
  ble,  // 蓝牙BLE
  sle,  // 星闪SLE (预留)
}

/// 电机状态
enum MotorStatus {
  idle,
  enabled,
  running,
  paused,
  error,
}

/// 运动方向
enum MotorDirection {
  forward,  // 正转
  backward, // 反转
}