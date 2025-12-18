import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_scanner/src/method_channel/mobile_scanner_method_channel.dart';

/// Test screen to verify torch state stream events are being emitted.
///
/// This screen demonstrates an issue where toggling the torch does not
/// emit events to the platform's torchStateStream.
class TorchStateTestScreen extends StatefulWidget {
  /// Creates a new [TorchStateTestScreen].
  const TorchStateTestScreen({super.key});

  @override
  State<TorchStateTestScreen> createState() => _TorchStateTestScreenState();
}

class _TorchStateTestScreenState extends State<TorchStateTestScreen> {
  late final MobileScannerController _controller;
  StreamSubscription<TorchState>? _torchStateSubscription;
  StreamSubscription<Map<Object?, Object?>>? _rawEventsSubscription;

  /// Count of torch state events received from the platform stream.
  int _streamEventCount = 0;

  /// Count of ALL events received from the raw events stream.
  int _rawEventCount = 0;

  /// Last torch state received from the platform stream.
  TorchState? _lastStreamState;

  /// Timestamps of received events for debugging.
  final List<String> _eventLog = [];

  @override
  void initState() {
    super.initState();

    // Debug: Print platform and stream info
    final MobileScannerPlatform platform = MobileScannerPlatform.instance;
    debugPrint('Platform instance: ${platform.hashCode}');
    debugPrint('Platform type: ${platform.runtimeType}');

    if (platform is MethodChannelMobileScanner) {
      final Stream<Map<Object?, Object?>> stream1 = platform.eventsStream;
      debugPrint('eventsStream (1st access): ${stream1.hashCode}');

      final Stream<Map<Object?, Object?>> stream2 = platform.eventsStream;
      debugPrint('eventsStream (2nd access): ${stream2.hashCode}');
      debugPrint('Same stream? ${identical(stream1, stream2)}');

      _rawEventsSubscription = stream1.listen(
        (Map<Object?, Object?> event) {
          debugPrint('RAW EVENT RECEIVED: $event');
          setState(() {
            _rawEventCount++;
            final String name = event['name']?.toString() ?? 'unknown';
            _eventLog.add(
              '${DateTime.now().toString().substring(11, 19)}: '
              'RawEvent: $name',
            );
            if (_eventLog.length > 10) {
              _eventLog.removeAt(0);
            }
          });
        },
        onError: (Object e) => debugPrint('RAW STREAM ERROR: $e'),
        onDone: () => debugPrint('RAW STREAM DONE'),
      );
    }

    // Subscribe to torch state stream BEFORE creating controller
    final Stream<TorchState> torchStream =
        MobileScannerPlatform.instance.torchStateStream;
    debugPrint('torchStateStream: ${torchStream.hashCode}');

    _torchStateSubscription = torchStream.listen(
      (TorchState state) {
        debugPrint('TORCH STATE EVENT RECEIVED: $state');
        setState(() {
          _streamEventCount++;
          _lastStreamState = state;
          _eventLog.add(
            '${DateTime.now().toString().substring(11, 19)}: '
            'TorchStream: ${state.name}',
          );
          if (_eventLog.length > 10) {
            _eventLog.removeAt(0);
          }
        });
      },
      onError: (Object e) => debugPrint('TORCH STREAM ERROR: $e'),
      onDone: () => debugPrint('TORCH STREAM DONE'),
    );

    // Create controller AFTER subscribing
    debugPrint('Creating controller...');
    _controller = MobileScannerController();
    debugPrint('Controller created, starting...');
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _torchStateSubscription?.cancel();
    _rawEventsSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    final String timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _eventLog.add('$timestamp: Toggle torch called');
      if (_eventLog.length > 10) {
        _eventLog.removeAt(0);
      }
    });

    await _controller.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Torch State Stream Test'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Column(
        children: [
          // Camera preview (small)
          SizedBox(
            height: 200,
            child: MobileScanner(controller: _controller),
          ),

          // Test results
          Expanded(
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Torch State Stream Test',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This test verifies if torchStateStream emits events '
                    'when toggleTorch() is called.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Divider(height: 24),

                  // Controller state
                  ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (context, state, _) {
                      return _buildStatusRow(
                        'Controller torchState:',
                        state.torchState.name,
                        _getTorchColor(state.torchState),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // Stream state
                  _buildStatusRow(
                    'Stream torchState:',
                    _lastStreamState?.name ?? 'No events yet',
                    _lastStreamState != null
                        ? _getTorchColor(_lastStreamState!)
                        : Colors.grey,
                  ),
                  const SizedBox(height: 8),

                  // Event count
                  _buildStatusRow(
                    'Stream event count:',
                    '$_streamEventCount',
                    _streamEventCount > 0 ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 8),

                  // Raw event count
                  _buildStatusRow(
                    'Raw event count:',
                    '$_rawEventCount',
                    _rawEventCount > 0 ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 16),

                  // Expected behavior
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expected behavior:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• Stream event count should increase each time '
                          'torch is toggled\n'
                          '• Stream torchState should match Controller '
                          'torchState',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Event log
                  const Text(
                    'Event Log:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _eventLog.length,
                        itemBuilder: (context, index) {
                          final String log = _eventLog[index];
                          final bool isToggleCall = log.contains('Toggle');
                          return Text(
                            log,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color:
                                  isToggleCall ? Colors.yellow : Colors.green,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Toggle button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _toggleTorch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.flashlight_on),
              label: const Text(
                'Toggle Torch',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: valueColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: valueColor),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Color _getTorchColor(TorchState state) {
    switch (state) {
      case TorchState.on:
        return Colors.orange;
      case TorchState.off:
        return Colors.blueGrey;
      case TorchState.auto:
        return Colors.purple;
      case TorchState.unavailable:
        return Colors.grey;
    }
  }
}
