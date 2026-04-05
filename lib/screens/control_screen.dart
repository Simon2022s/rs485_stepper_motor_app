import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/motor_provider.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  int _currentIndex = 0;
  final TextEditingController _manualCmdController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  // Motion Settings文本框Control器
  final TextEditingController _speedController = TextEditingController();
  final TextEditingController _accelController = TextEditingController();
  final TextEditingController _decelController = TextEditingController();
  final TextEditingController _displacementController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _positionController.text = '0';
    // InitializeMotion SettingsControl器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final motor = context.read<MotorProvider>();
      _speedController.text = motor.speed.toString();
      _accelController.text = motor.acceleration.toString();
      _decelController.text = motor.deceleration.toString();
      _displacementController.text = motor.displacement.toString();
    });
  }

  @override
  void dispose() {
    _manualCmdController.dispose();
    _positionController.dispose();
    _speedController.dispose();
    _accelController.dispose();
    _decelController.dispose();
    _displacementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _ControlPanel(),
          _ParametersPage(),
          _LogsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF2D2D2D),
        selectedItemColor: const Color(0xFF00A1CB),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Control'),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Parameters'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Logs'),
        ],
      ),
    );
  }
}

/// Control面板页面
class _ControlPanel extends StatefulWidget {
  const _ControlPanel({super.key});

  @override
  State<_ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<_ControlPanel> {
  final TextEditingController _manualCmdController = TextEditingController();
  // Motion Settings文本框Control器 - 保持状态避免重建时丢失焦点
  final TextEditingController _speedController = TextEditingController();
  final TextEditingController _accelController = TextEditingController();
  final TextEditingController _decelController = TextEditingController();
  final TextEditingController _displacementController = TextEditingController();

  @override
  void dispose() {
    _manualCmdController.dispose();
    _speedController.dispose();
    _accelController.dispose();
    _decelController.dispose();
    _displacementController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // InitializeMotion SettingsControl器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final motor = context.read<MotorProvider>();
      _speedController.text = motor.speed.toString();
      _accelController.text = motor.acceleration.toString();
      _decelController.text = motor.deceleration.toString();
      _displacementController.text = motor.displacement.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final connProvider = Provider.of<ConnectionProvider>(context, listen: true);
    final motor = Provider.of<MotorProvider>(context, listen: true);
    final bleDevice = connProvider.bleDevice;

    // Settings蓝牙Device和特征值
    if (bleDevice != null) {
      motor.setBLEDevice(bleDevice);
      
      // 传递缓存的Write特征值
      if (connProvider.cachedWriteCharacteristic != null) {
        motor.setCachedWriteCharacteristic(connProvider.cachedWriteCharacteristic);
        print('ControlPanel: Write characteristic set to MotorProvider');
      }
      
      // 传递缓存的Notify特征值
      if (connProvider.cachedNotifyCharacteristic != null) {
        motor.setCachedNotifyCharacteristic(connProvider.cachedNotifyCharacteristic);
        print('ControlPanel: Notify characteristic set to MotorProvider');
      }
      
      print('ControlPanel: Bluetooth device set to MotorProvider: ${bleDevice.name}');
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Motor ${motor.motorId}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(bleDevice?.name ?? 'Not Connected', style: TextStyle(color: bleDevice != null ? const Color(0xFF4CAF50) : const Color(0xFFFF5722), fontSize: 12)),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    if (motor.isEnabled) {
                      motor.disable();
                    } else {
                      motor.enable();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: motor.isEnabled ? const Color(0xFF4CAF50) : const Color(0xFFFF5722),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(motor.isEnabled ? 'Disable' : 'Enable', style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Real-time Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusItem('Speed', motor.realSpeed != 0 ? '${motor.realSpeed}' : '${motor.speed}', motor.realSpeed != 0 ? '(${motor.ppr > 0 ? (motor.realSpeed * 60 ~/ motor.ppr) : 0} rpm)' : '(${motor.ppr > 0 ? (motor.speed * 60 ~/ motor.ppr) : 0} rpm)'),
                  _buildStatusItem('Position', motor.realPosition != 0 ? '${motor.realPosition}' : '0', 'pulses'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Velocity Control
            const Text('Velocity Control', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton('Forward', Icons.arrow_forward, motor.forward, color: const Color(0xFF4CAF50), height: 55),
                _buildControlButton('Stop', Icons.stop_circle_outlined, motor.stop, color: const Color(0xFFFF9800), height: 55),
                _buildControlButton('Backward', Icons.arrow_back, motor.backward, color: const Color(0xFFF44336), height: 55),
              ],
            ),

            const SizedBox(height: 16),

            // Position Control
            const Text('Position Control', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton('MovAbs', Icons.vertical_align_bottom, motor.moveAbsolute, color: const Color(0xFF2196F3), height: 55),
                _buildControlButton('Zero', Icons.center_focus_strong, motor.zero, color: const Color(0xFF9C27B0), height: 55),
                _buildControlButton('MovRel', Icons.swap_vert, motor.moveRelative, color: const Color(0xFF009688), height: 55),
              ],
            ),

            const SizedBox(height: 16),

            // Motion Settings
            const Text('Motion Settings', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            
            // Speed - 使用state中的controller
            _buildSettingRowWithController('Speed(pps)', _speedController, (value) {
              int? speed = int.tryParse(value);
              if (speed != null) motor.setSpeed(speed);
            }, () => motor.applySpeed()),
            
            const SizedBox(height: 8),
            
            // Acceleration - 使用state中的controller
            _buildSettingRowWithController('Acceleration', _accelController, (value) {
              int? accel = int.tryParse(value);
              if (accel != null) motor.setAcceleration(accel);
            }, () => motor.applyAcceleration()),
            
            const SizedBox(height: 8),
            
            // Deceleration - 使用state中的controller
            _buildSettingRowWithController('Deceleration', _decelController, (value) {
              int? decel = int.tryParse(value);
              if (decel != null) motor.setDeceleration(decel);
            }, () => motor.applyDeceleration()),
            
            const SizedBox(height: 8),
            
            // Displacement - 使用state中的controller
            _buildSettingRowWithController('Displacement', _displacementController, (value) {
              int? disp = int.tryParse(value);
              if (disp != null) motor.setDisplacement(disp);
            }, () => motor.applyDisplacement()),

            const SizedBox(height: 16),

            // Query Status
            const Text('Query Status', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton('Query Speed', Icons.speed, motor.querySpeed, color: const Color(0xFF00BCD4), width: 150, height: 55),
                _buildControlButton('Query Position', Icons.location_on_outlined, motor.queryPosition, color: const Color(0xFF673AB7), width: 150, height: 55),
              ],
            ),

            const SizedBox(height: 16),

            // Manual Command
            const Text('Manual Command', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _manualCmdController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter hex command (e.g., 010300400002)',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                motor.sendManualCommand(_manualCmdController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A1CB),
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Send Command', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(unit, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  /// 构建Settings行（文本框 + Set按钮）- 使用传入的controller保持状态
  Widget _buildSettingRowWithController(String label, TextEditingController controller, Function(String) onChanged, VoidCallback onSet) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 32,
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              keyboardType: TextInputType.number,
              onChanged: onChanged,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          height: 32,
          child: ElevatedButton(
            onPressed: onSet,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A1CB),
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
            ),
            child: const Text('Set', style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ),
      ],
    );
  }

  /// 构建Control按钮 - 带圆角的长方形
  Widget _buildControlButton(String label, IconData icon, VoidCallback onPressed, {required Color color, double width = 100, double height = 70}) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Parameters页面
class _ParametersPage extends StatefulWidget {
  const _ParametersPage();

  @override
  State<_ParametersPage> createState() => _ParametersPageState();
}

class _ParametersPageState extends State<_ParametersPage> {
  // 文本框Control器 - 保持状态
  final TextEditingController _currentMaController = TextEditingController(text: '1000');
  final TextEditingController _pprController = TextEditingController(text: '3200');

  @override
  void initState() {
    super.initState();
    // Initialize时从motor provider同步PPR值
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final motor = context.read<MotorProvider>();
      _pprController.text = motor.ppr.toString();
    });
  }

  @override
  void dispose() {
    _currentMaController.dispose();
    _pprController.dispose();
    super.dispose();
  }

  /// 构建Parameters卡片
  Widget _buildParamCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final motor = Provider.of<MotorProvider>(context, listen: true);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Motor Parameters', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Motor ID
            _buildParamCard(
              title: 'Motor ID',
              subtitle: 'Device address (1-247)',
              child: TextField(
                controller: TextEditingController(text: motor.motorId.toString()),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  int? id = int.tryParse(value);
                  if (id != null) motor.setMotorId(id);
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Current mA
            _buildParamCard(
              title: 'Current mA',
              subtitle: 'Peak current in mA',
              child: TextField(
                controller: _currentMaController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // PPR
            _buildParamCard(
              title: 'PPR',
              subtitle: 'Pulses per revolution',
              child: TextField(
                controller: _pprController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  int? ppr = int.tryParse(value);
                  if (ppr != null) motor.setPpr(ppr);
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Standby Current %
            _buildParamCard(
              title: 'Standby Current %',
              subtitle: '0-100%',
              child: Slider(
                value: motor.current.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '${motor.current}%',
                onChanged: (value) {
                  motor.setCurrent(value.round());
                },
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Apply按钮
            ElevatedButton(
              onPressed: () {
                // Current mA: 01 06 00 00 [value_hex] CRC
                int? currentMa = int.tryParse(_currentMaController.text);
                if (currentMa != null) {
                  motor.applyCurrentMa(currentMa);
                }
                // PPR: 01 06 00 01 [value_hex] CRC - 使用文本框中的值
                int? ppr = int.tryParse(_pprController.text);
                if (ppr != null) {
                  motor.applyPPRValue(ppr);
                }
                motor.applyCurrent();
                motor.saveParams();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Apply Parameters', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logs页面
class _LogsPage extends StatelessWidget {
  const _LogsPage();

  @override
  Widget build(BuildContext context) {
    final motor = Provider.of<MotorProvider>(context, listen: true);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Communication Logs', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: motor.clearLogs,
                  icon: const Icon(Icons.clear_all, color: Colors.white),
                  tooltip: 'Clear Logs',
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF404040)),
              ),
              child: ListView.builder(
                reverse: true,
                itemCount: motor.logs.length,
                itemBuilder: (context, index) {
                  final log = motor.logs[motor.logs.length - 1 - index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      log,
                      style: const TextStyle(color: Color(0xFFA0FFD0), fontSize: 12, fontFamily: 'Monospace'),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}