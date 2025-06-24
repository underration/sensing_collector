import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../bloc/app_state.dart';

/// 位置タグ付与画面
class TagPositionScreen extends ConsumerStatefulWidget {
  const TagPositionScreen({super.key});

  @override
  ConsumerState<TagPositionScreen> createState() => _TagPositionScreenState();
}

class _TagPositionScreenState extends ConsumerState<TagPositionScreen> {
  final _xController = TextEditingController();
  final _yController = TextEditingController();
  int _selectedMode = 0; // 0: Manual, 1: QR, 2: GNSS
  MobileScannerController? _scannerController;
  bool _isGnssTracking = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final appStateNotifier = ref.read(appStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tag Position'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // モード選択
            _buildModeSelection(),
            
            const SizedBox(height: 24),
            
            // 選択されたモードに応じたUI
            Expanded(
              child: _buildModeContent(appState, appStateNotifier),
            ),
            
            const SizedBox(height: 16),
            
            // 保存ボタン
            _buildSaveButton(appState, appStateNotifier),
          ],
        ),
      ),
    );
  }

  /// モード選択
  Widget _buildModeSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Position Tag Mode',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    icon: Icons.edit,
                    label: 'Manual',
                    isSelected: _selectedMode == 0,
                    onTap: () => setState(() => _selectedMode = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModeButton(
                    icon: Icons.qr_code_scanner,
                    label: 'QR Code',
                    isSelected: _selectedMode == 1,
                    onTap: () => setState(() => _selectedMode = 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModeButton(
                    icon: Icons.gps_fixed,
                    label: 'GNSS',
                    isSelected: _selectedMode == 2,
                    onTap: () => setState(() => _selectedMode = 2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// モードボタン
  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// モード別コンテンツ
  Widget _buildModeContent(AppState appState, AppStateNotifier notifier) {
    switch (_selectedMode) {
      case 0:
        return _buildManualInput();
      case 1:
        return _buildQrScanner();
      case 2:
        return _buildGnssTracking(appState, notifier);
      default:
        return const SizedBox.shrink();
    }
  }

  /// 手動入力
  Widget _buildManualInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Coordinates',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _xController,
              decoration: const InputDecoration(
                labelText: 'X Coordinate',
                border: OutlineInputBorder(),
                hintText: 'Enter X coordinate',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _yController,
              decoration: const InputDecoration(
                labelText: 'Y Coordinate',
                border: OutlineInputBorder(),
                hintText: 'Enter Y coordinate',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  /// QRスキャナー
  Widget _buildQrScanner() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QR Code Scanner',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        _handleQrResult(barcode.rawValue!);
                      }
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Point camera at QR code containing coordinates',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// GNSS追跡
  Widget _buildGnssTracking(AppState appState, AppStateNotifier notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GNSS Location Tracking',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _isGnssTracking ? Icons.gps_fixed : Icons.gps_off,
                  color: _isGnssTracking ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _isGnssTracking ? 'Tracking Active' : 'Tracking Inactive',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isGnssTracking ? Colors.green : Colors.grey,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    if (_isGnssTracking) {
                      await notifier.stopGnssTracking();
                      setState(() => _isGnssTracking = false);
                    } else {
                      try {
                        await notifier.startGnssTracking();
                        setState(() => _isGnssTracking = true);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to start GNSS: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: Text(_isGnssTracking ? 'Stop' : 'Start'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isGnssTracking) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.location_on, color: Colors.green),
                    const SizedBox(height: 8),
                    const Text(
                      'Location tracking is active',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Current position will be automatically tagged to collected data',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.gps_off, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text(
                      'Location tracking is inactive',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Press Start to begin automatic location tagging',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 保存ボタン
  Widget _buildSaveButton(AppState appState, AppStateNotifier notifier) {
    return ElevatedButton(
      onPressed: _canSave() ? () => _savePosition(notifier) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: const Text(
        'Save Position',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// 保存可能かチェック
  bool _canSave() {
    switch (_selectedMode) {
      case 0: // Manual
        return _xController.text.isNotEmpty && _yController.text.isNotEmpty;
      case 1: // QR
        return _xController.text.isNotEmpty && _yController.text.isNotEmpty;
      case 2: // GNSS
        return _isGnssTracking;
      default:
        return false;
    }
  }

  /// 位置を保存
  Future<void> _savePosition(AppStateNotifier notifier) async {
    try {
      switch (_selectedMode) {
        case 0: // Manual
          final x = double.parse(_xController.text);
          final y = double.parse(_yController.text);
          await notifier.addManualLocationLabel(x, y);
          break;
        case 1: // QR
          // QRコードの結果は既に処理済み
          break;
        case 2: // GNSS
          // GNSSは自動的に処理される
          break;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Position saved successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save position: $e')),
        );
      }
    }
  }

  /// QR結果を処理
  void _handleQrResult(String qrData) {
    try {
      // QRコードから座標を解析
      final coordinates = _parseQrCoordinates(qrData);
      if (coordinates != null) {
        setState(() {
          _xController.text = coordinates['x'].toString();
          _yController.text = coordinates['y'].toString();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR Code detected: X=${coordinates['x']}, Y=${coordinates['y']}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR code format')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to parse QR code: $e')),
      );
    }
  }

  /// QRコードから座標を解析
  Map<String, double>? _parseQrCoordinates(String qrData) {
    try {
      if (qrData.contains('x:') && qrData.contains('y:')) {
        final xMatch = RegExp(r'x:([\d.-]+)').firstMatch(qrData);
        final yMatch = RegExp(r'y:([\d.-]+)').firstMatch(qrData);
        
        if (xMatch != null && yMatch != null) {
          return {
            'x': double.parse(xMatch.group(1)!),
            'y': double.parse(yMatch.group(1)!),
          };
        }
      } else {
        final parts = qrData.split(',');
        if (parts.length == 2) {
          return {
            'x': double.parse(parts[0].trim()),
            'y': double.parse(parts[1].trim()),
          };
        }
      }
    } catch (e) {
      print('Failed to parse QR coordinates: $e');
    }
    return null;
  }
} 