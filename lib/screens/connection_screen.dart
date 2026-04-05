import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/motor_provider.dart';
import '../utils/constants.dart';
import '../utils/serial_config.dart';
import 'control_screen.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Connect Device', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: Consumer<ConnectionProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: _buildTypeButton(context, 'Bluetooth BLE', ConnectionType.ble, provider)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTypeButton(context, 'Star Light SLE', ConnectionType.sle, provider)),
                  ],
                ),
              ),
              // Baud Rate选择
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF404040)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.speed, color: Colors.grey, size: 20),
                      const SizedBox(width: 12),
                      const Text('Baud Rate:', style: TextStyle(color: Colors.white, fontSize: 14)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: provider.baudRate,
                            dropdownColor: const Color(0xFF2D2D2D),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            isExpanded: true,
                            items: SerialConfig.supportedBaudRates.map((int baudRate) {
                              return DropdownMenuItem<int>(
                                value: baudRate,
                                child: Text('$baudRate bps', style: const TextStyle(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: provider.isConnected
                                ? null  // Connect后不能修改Baud Rate
                                : (int? newValue) {
                                    if (newValue != null) {
                                      provider.setBaudRate(newValue);
                                    }
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: provider.isScanning ? null : () => provider.startScan(),
                        icon: Icon(provider.isScanning ? Icons.hourglass_empty : Icons.bluetooth_searching),
                        label: Text(provider.isScanning ? 'Scanning...' : 'Scan Devices'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          provider.demoConnect();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ControlScreen()));
                        },
                        icon: const Icon(Icons.preview),
                        label: const Text('Demo Mode (Preview UI)'),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF9800), side: const BorderSide(color: Color(0xFFFF9800)), padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: provider.devices.isEmpty
                    ? const Center(child: Text('Tap Scan to search devices', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: provider.devices.length,
                        itemBuilder: (context, index) {
                          final device = provider.devices[index];
                          return Card(
                            color: const Color(0xFF2D2D2D),
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: Icon(device.connectionType == ConnectionType.ble ? Icons.bluetooth : Icons.wifi, color: const Color(0xFF2196F3)),
                              title: Text(device.name, style: const TextStyle(color: Colors.white)),
                              subtitle: Text(device.id, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                              onTap: () async {
                                bool success = await provider.connect(device);
                                if (success && context.mounted) {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => ControlScreen()));
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
              if (provider.isConnected)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF2D2D2D),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Connected: ${provider.connectedDeviceName}', style: const TextStyle(color: Colors.white))),
                          TextButton(onPressed: () => provider.disconnect(), child: const Text('Disconnect')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Serial Configuration状态
                      if (provider.isConfiguringSerial)
                        Row(
                          children: [
                            const Icon(Icons.settings, color: Colors.orange, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                provider.serialConfigStatus,
                                style: const TextStyle(color: Colors.orange, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        )
                      else if (provider.serialConfigured)
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                provider.serialConfigStatus,
                                style: const TextStyle(color: Colors.green, fontSize: 12),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.yellow, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                provider.serialConfigStatus,
                                style: const TextStyle(color: Colors.yellow, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTypeButton(BuildContext context, String text, ConnectionType type, ConnectionProvider provider) {
    bool selected = provider.connectionType == type;
    return GestureDetector(
      onTap: () => provider.setConnectionType(type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2196F3) : const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF2196F3) : Colors.grey),
        ),
        child: Center(
          child: Text(text, style: TextStyle(color: selected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
