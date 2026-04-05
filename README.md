# NEMA 23 Stepper Motor Control App

A Flutter-based Android application for controlling NEMA 23 Modbus RTU stepper motors via Bluetooth BLE.

## Features

- **Bluetooth Connection**: Connect to BLE-enabled serial modules (DTU)
- **Motor Control**: Forward, backward, stop, absolute/relative positioning
- **Real-time Status**: Monitor speed and position in real-time
- **Parameter Configuration**: Adjust current, PPR, acceleration settings
- **Modbus RTU Protocol**: Industry-standard communication protocol with CRC16 validation

## Product

This app is designed for the **NEMA 23 Modbus RTU Integrated Stepper Motor**:
- [Product Page](https://www.adampower.de/nema23-modbus-rtu-integrated-stepper-motor)

## Hardware Requirements

- NEMA 23 Stepper Motor with Modbus RTU interface
- Bluetooth DTU module (BLE to RS485)
- Android device with Bluetooth support

## Communication Protocol

The app uses Modbus RTU over BLE:
- **Baud Rate**: 9600-115200 bps (configurable)
- **Data Bits**: 8
- **Stop Bits**: 1
- **Parity**: None
- **CRC16**: Required for all commands

### Example Commands

| Function | Command |
|----------|---------|
| Forward | `01 06 00 46 00 04 [CRC]` |
| Backward | `01 06 00 46 00 03 [CRC]` |
| Stop | `01 06 00 46 00 05 [CRC]` |
| Query Speed | `01 03 00 40 00 02 [CRC]` |
| Query Position | `01 03 00 27 00 02 [CRC]` |

## Installation

### Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/nema23-stepper-app.git
cd nema23-stepper-app

# Get dependencies
flutter pub get

# Build APK
flutter build apk --release
```

### Pre-built APK

Download the latest APK from the Releases page.

## Usage

1. **Connect**: Open app, scan for BLE devices, select your DTU module
2. **Configure**: Set baud rate to match your motor driver
3. **Control**: Use control panel to operate motor
4. **Monitor**: View real-time speed and position

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── connection_device.dart
│   └── motor_config.dart
├── providers/                # State management
│   ├── connection_provider.dart
│   └── motor_provider.dart
├── screens/                  # UI screens
│   ├── connection_screen.dart
│   └── control_screen.dart
├── services/                 # Business logic
│   ├── ble_service.dart      # Bluetooth communication
│   ├── modbus_service.dart   # Modbus protocol
│   └── storage_service.dart  # Local storage
└── utils/                    # Utilities
    ├── constants.dart
    ├── modbus_crc.dart
    ├── serial_config.dart
    └── debug_helper.dart
```

## Tech Stack

- **Framework**: Flutter 3.x
- **State Management**: Provider
- **Bluetooth**: flutter_blue_plus
- **Architecture**: Clean Architecture

## License

MIT License

## Author

Developed for adampower.de

## Related Links

- [Product Website](https://www.adampower.de/)
- [Motor Documentation](https://www.adampower.de/nema23-modbus-rtu-integrated-stepper-motor)
