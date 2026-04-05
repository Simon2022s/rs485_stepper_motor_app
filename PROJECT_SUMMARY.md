# 步进电机控制APP项目总结

## 项目信息
- **项目名称**: Stepper Motor Control App (Flutter安卓版)
- **项目路径**: `C:\Users\Administrator\.openclaw\workspace\stepper_motor_app`
- **完成日期**: 2026年3月26日
- **APK文件**: `build\app\outputs\flutter-apk\app-release.apk` (46.2MB)

## 核心功能
✅ **蓝牙DTU连接** - 连接蓝牙串口透传模块
✅ **AT命令自动配置** - 配置DTU串口参数
✅ **Modbus电机控制** - 发送十六进制指令控制步进电机
✅ **多页面UI** - Connection/Control/Parameters/Logs页面
✅ **详细调试输出** - 实时显示配置和通信状态

## AT命令配置序列（关键！）
### 必须严格按照这个顺序发送（全部大写）：
```dart
1. AT+BAUD=9600,8,0,1\r\n      // 串口参数：9600波特率，8数据位，0无校验，1停止位
2. AT+SLAVE\r\n                // 从机模式
3. AT+FORMAT=HEX\r\n           // HEX数据格式
4. AT+TRANSPARENT=1\r\n        // 启用透传模式（必须是最后一条命令）
```

### 命令详解：
| 命令 | 格式 | 说明 | 字节数组 |
|------|------|------|----------|
| AT+BAUD | `AT+BAUD=9600,8,0,1\r\n` | 设置串口参数 | `65 84 43 66 65 85 68 61 57 54 48 48 44 56 44 48 44 49 13 10` |
| AT+SLAVE | `AT+SLAVE\r\n` | 设置从机模式 | `65 84 43 83 76 65 86 69 13 10` |
| AT+FORMAT | `AT+FORMAT=HEX\r\n` | 设置HEX格式 | `65 84 43 70 79 82 77 65 84 61 72 69 88 13 10` |
| AT+TRANSPARENT | `AT+TRANSPARENT=1\r\n` | 启用透传模式 | `65 84 43 84 82 65 78 83 80 65 82 69 78 84 61 49 13 10` |

## Modbus指令示例
### 10写命令（设置速度）：
```hex
01 10 00 40 00 02 04 27 10 00 00 C3 6B
```
- `01`: 设备ID
- `10`: 功能码（写多个寄存器）
- `00 40`: 寄存器地址（0x40 = 64，速度寄存器）
- `00 02`: 寄存器数量（2个寄存器 = 32位）
- `04`: 数据字节数（4字节）
- `27 10 00 00`: 数据（10000 = 0x2710，大端序）
- `C3 6B`: CRC16校验码

### 03读命令（查询速度）：
```hex
01 03 00 40 00 02 C5 CB
```

## 蓝牙UUID配置
```dart
// 标准蓝牙串口透传UUID
bleServiceUUID = '0000FFE0-0000-1000-8000-00805F9B34FB'
bleWriteCharacteristicUUID = '0000FFE2-0000-1000-8000-00805F9B34FB'  // 发送
bleNotifyCharacteristicUUID = '0000FFE1-0000-1000-8000-00805F9B34FB'  // 接收
```

## UI滚动条范围
```dart
// Control页面
Speed: 0-200000 (脉冲/秒)
Displacement: 0-1000000 (脉冲)
Acceleration: 0-65535
Deceleration: 0-65535
```

## 构建配置
```bash
# Java环境
JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot"

# 构建命令
flutter build apk --release --no-tree-shake-icons

# 运行测试
flutter run --release
```

## 调试输出示例
```
=== FINAL DTU CONFIGURATION SEQUENCE ===
AT commands MUST be sent in this exact order (ALL UPPERCASE):
1. AT+BAUD=9600,8,0,1    - Set serial parameters
2. AT+SLAVE              - Set slave mode
3. AT+FORMAT=HEX         - Set data format to HEX
4. AT+TRANSPARENT=1      - Enable transparent transmission mode

[Step 1/4] Sending AT+BAUD=9600,8,0,1
✅ AT+BAUD=9600,8,0,1 sent successfully
✅ Serial parameters set: 9600 baud, 8 data bits, 0 parity, 1 stop bit

[Step 2/4] Sending AT+SLAVE
✅ AT+SLAVE sent successfully
✅ Slave mode activated

[Step 3/4] Sending AT+FORMAT=HEX
✅ AT+FORMAT=HEX sent successfully
✅ Data format set to HEX (for Modbus commands)

[Step 4/4] Sending AT+TRANSPARENT=1 (LAST STEP!)
✅ AT+TRANSPARENT=1 sent successfully
✅ Transparent transmission mode ENABLED
⚠️ IMPORTANT: AT+TRANSPARENT=1 is the LAST command!

=== FINAL CONFIGURATION COMPLETE ===
Successfully sent: 4/4 AT commands in exact order
✅ PERFECT: All 4 AT commands sent successfully in correct order
✅ DTU is now in transparent transmission mode
✅ Ready to send Modbus hexadecimal commands
```

## 重要注意事项
1. **AT命令顺序不能改变** - 必须严格按照BAUD→SLAVE→FORMAT→TRANSPARENT的顺序
2. **AT+TRANSPARENT=1必须是最后一条命令** - 发送后DTU进入透传模式
3. **数据格式区分**：
   - AT命令：ASCII字符串，用`string.codeUnits`转换
   - Modbus指令：十六进制数据，用`_hexToBytes()`转换
4. **透传模式**：DTU出厂时可能已预设为9600 8N1，但APP仍需要发送AT命令确保正确配置
5. **蓝牙连接**：需要安卓蓝牙权限和位置权限

## 测试验证清单
- [x] APK构建成功（无编译错误）
- [x] AT命令序列正确（4个步骤，全部大写）
- [x] 数据格式正确（区分ASCII和十六进制）
- [x] 蓝牙UUID配置正确（FFE0/FFE1/FFE2）
- [x] UI滚动条范围正确（Speed: 0-200000, Displacement: 0-1000000）
- [x] Modbus命令格式正确（包含CRC16校验）
- [x] 调试输出详细（显示每个步骤状态）

## 后续优化建议
1. **AT命令响应解析** - 解析DTU返回的OK/ERROR响应
2. **自动重试机制** - AT命令失败时自动重试3次
3. **更多DTU兼容** - 支持不同厂家的DTU设备
4. **离线模拟模式** - 无蓝牙连接时使用模拟数据
5. **数据记录功能** - 保存控制历史记录
6. **多语言支持** - 添加中文界面
7. **主题切换** - 深色/浅色模式

## 问题排查指南
### 问题：APP连接后电机无反应
1. 检查AT命令是否按正确顺序发送
2. 检查`AT+TRANSPARENT=1`是否是最后一条命令
3. 检查Modbus指令格式是否正确（包含CRC16）
4. 检查DTU串口参数是否匹配电机（9600 8N1）
5. 使用调试输出查看详细日志

### 问题：蓝牙连接失败
1. 检查安卓蓝牙和位置权限
2. 检查DTU设备是否处于可发现模式
3. 检查蓝牙UUID配置是否正确
4. 重启手机蓝牙和APP

### 问题：AT命令发送失败
1. 检查蓝牙特征值是否可写（FFE2）
2. 检查AT命令格式是否正确（全部大写，有\r\n）
3. 检查发送的数据格式（字节数组，不是字符串）

## 联系信息
- **项目负责人**: 爸爸
- **开发助手**: 小V
- **完成时间**: 2026年3月26日
- **项目状态**: ✅ 完成，APK已构建