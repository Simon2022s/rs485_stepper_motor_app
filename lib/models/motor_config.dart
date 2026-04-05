import '../utils/constants.dart';

/// 电机ConfigureData模型
class MotorConfig {
  int deviceId;
  int speed;
  int acceleration;
  int deceleration;
  int displacement;
  int current;
  int peakCurrent;
  int ppr;
  MotorDirection direction;
  bool isEnabled;
  MotorStatus status;

  MotorConfig({
    this.deviceId = 1,
    this.speed = 1000,
    this.acceleration = 1000,
    this.deceleration = 1000,
    this.displacement = 0,
    this.current = 50,
    this.peakCurrent = 100,
    this.ppr = 200,
    this.direction = MotorDirection.forward,
    this.isEnabled = false,
    this.status = MotorStatus.idle,
  });

  /// 创建默认Configure
  factory MotorConfig.defaultConfig() {
    return MotorConfig();
  }

  /// 从JSON创建
  factory MotorConfig.fromJson(Map<String, dynamic> json) {
    return MotorConfig(
      deviceId: json['deviceId'] ?? 1,
      speed: json['speed'] ?? 1000,
      acceleration: json['acceleration'] ?? 1000,
      deceleration: json['deceleration'] ?? 1000,
      displacement: json['displacement'] ?? 0,
      current: json['current'] ?? 50,
      peakCurrent: json['peakCurrent'] ?? 100,
      ppr: json['ppr'] ?? 200,
      direction: MotorDirection.values[json['direction'] ?? 0],
      isEnabled: json['isEnabled'] ?? false,
      status: MotorStatus.values[json['status'] ?? 0],
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'speed': speed,
      'acceleration': acceleration,
      'deceleration': deceleration,
      'displacement': displacement,
      'current': current,
      'peakCurrent': peakCurrent,
      'ppr': ppr,
      'direction': direction.index,
      'isEnabled': isEnabled,
      'status': status.index,
    };
  }

  /// CopyConfigure
  MotorConfig copyWith({
    int? deviceId,
    int? speed,
    int? acceleration,
    int? deceleration,
    int? displacement,
    int? current,
    int? peakCurrent,
    int? ppr,
    MotorDirection? direction,
    bool? isEnabled,
    MotorStatus? status,
  }) {
    return MotorConfig(
      deviceId: deviceId ?? this.deviceId,
      speed: speed ?? this.speed,
      acceleration: acceleration ?? this.acceleration,
      deceleration: deceleration ?? this.deceleration,
      displacement: displacement ?? this.displacement,
      current: current ?? this.current,
      peakCurrent: peakCurrent ?? this.peakCurrent,
      ppr: ppr ?? this.ppr,
      direction: direction ?? this.direction,
      isEnabled: isEnabled ?? this.isEnabled,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'MotorConfig(deviceId: $deviceId, speed: $speed, accel: $acceleration, '
        'decel: $deceleration, displacement: $displacement, current: $current, '
        'ppr: $ppr, direction: $direction, enabled: $isEnabled, status: $status)';
  }
}