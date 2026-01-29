import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const ScreenGuardApp());
}

class ScreenGuardApp extends StatelessWidget {
  const ScreenGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScreenGuard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.example.screenguard/overlay');

  bool _hasPermission = false;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
    _setupMethodCallHandler();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPermissionResult') {
        setState(() {
          _hasPermission = call.arguments as bool;
        });
      }
    });
  }

  Future<void> _checkStatus() async {
    try {
      final hasPermission =
          await _channel.invokeMethod<bool>('checkOverlayPermission');
      final isActive = await _channel.invokeMethod<bool>('isOverlayActive');
      setState(() {
        _hasPermission = hasPermission ?? false;
        _isActive = isActive ?? false;
      });
    } on PlatformException {
      // Channel not ready yet
    }
  }

  Future<void> _requestPermission() async {
    await _channel.invokeMethod('requestOverlayPermission');
  }

  Future<void> _toggleOverlay() async {
    if (!_hasPermission) {
      _requestPermission();
      return;
    }
    try {
      if (_isActive) {
        await _channel.invokeMethod('stopOverlay');
      } else {
        await _channel.invokeMethod('startOverlay');
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed to toggle overlay')),
        );
      }
    }
    await _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isActive ? Icons.lock : Icons.lock_outline,
                size: 64,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),
              Text(
                'ScreenGuard',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Lock your screen, keep audio playing',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white60,
                    ),
              ),
              const SizedBox(height: 48),
              _StatusRow(
                icon: _hasPermission ? Icons.check_circle : Icons.warning,
                color: _hasPermission ? Colors.green : Colors.orange,
                label: _hasPermission
                    ? 'Overlay permission granted'
                    : 'Overlay permission required',
                actionLabel: _hasPermission ? null : 'Grant',
                onAction: _hasPermission ? null : _requestPermission,
              ),
              const SizedBox(height: 12),
              _StatusRow(
                icon: _isActive ? Icons.lock : Icons.lock_open,
                color: _isActive ? Colors.green : Colors.grey,
                label: _isActive ? 'Screen lock active' : 'Screen lock inactive',
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 200,
                height: 200,
                child: ElevatedButton(
                  onPressed: _toggleOverlay,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: _isActive ? Colors.red : Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isActive ? Icons.stop : Icons.play_arrow,
                        size: 64,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isActive ? 'STOP' : 'START',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'U-shape swipe to unlock\n'
                  'Or tap emergency text 20x within 5 seconds',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white38,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusRow({
    required this.icon,
    required this.color,
    required this.label,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
