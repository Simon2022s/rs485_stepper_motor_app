/// Modbus CRC16 校验工具
/// 来自原Python项目的crc.py
class ModbusCRC {
  /// 计算CRC16校验码
  static List<int> calcCRC(List<int> data) {
    int crc = 0xFFFF;
    for (int pos in data) {
      crc ^= pos;
      for (int i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc >>= 1;
          crc ^= 0xA001;
        } else {
          crc >>= 1;
        }
      }
    }
    return [crc & 0xFF, (crc >> 8) & 0xFF];
  }

  /// 计算CRC16并返回Hex字符串
  static String calcCRCHex(String hexString) {
    List<int> data = _hexToBytes(hexString);
    List<int> crc = calcCRC(data);
    return '${crc[0].toRadixString(16).padLeft(2, '0').toUpperCase()}${crc[1].toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  /// 构建完整的Modbus RTUFrame
  static String buildFrame(int deviceId, int function, String dataHex) {
    List<int> data = _hexToBytes(dataHex);
    List<int> frame = [deviceId, function, ...data];
    List<int> crc = calcCRC(frame);
    String frameHex = _bytesToHex(frame);
    return '$frameHex${crc[0].toRadixString(16).padLeft(2, '0').toUpperCase()}${crc[1].toRadixString(16).padLeft(2, '0').toUpperCase()}';
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
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
  }
}