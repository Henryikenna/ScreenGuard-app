import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const _channel = MethodChannel('com.screenguard.app/overlay');

  bool _hasPermission = false;
  bool _isActive = false;
  int _delaySeconds = 5;
  int? _countdown;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
    _setupMethodCallHandler();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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
      final hasPermission = await _channel.invokeMethod<bool>(
        'checkOverlayPermission',
      );
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

  void _startCountdown() {
    setState(() {
      _countdown = _delaySeconds;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown = _countdown! - 1;
      });
      if (_countdown! <= 0) {
        timer.cancel();
        _countdownTimer = null;
        _activateOverlay();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() {
      _countdown = null;
    });
  }

  Future<void> _activateOverlay() async {
    setState(() {
      _countdown = null;
    });
    try {
      await _channel.invokeMethod('startOverlay');
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed to start overlay')),
        );
      }
    }
    await _checkStatus();
  }

  Future<void> _toggleOverlay() async {
    if (!_hasPermission) {
      _requestPermission();
      return;
    }
    if (_countdown != null) {
      _cancelCountdown();
      return;
    }
    if (_isActive) {
      try {
        await _channel.invokeMethod('stopOverlay');
      } on PlatformException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'Failed to stop overlay')),
          );
        }
      }
      await _checkStatus();
    } else {
      _startCountdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCounting = _countdown != null;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.info_outline),
                color: Colors.white54,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DeveloperInfoPage(),
                    ),
                  );
                },
              ),
            ),
            Center(
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.white60),
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
                    label: _isActive
                        ? 'Screen lock active'
                        : 'Screen lock inactive',
                  ),
                  const SizedBox(height: 24),
                  // Delay selector
                  if (!_isActive && !isCounting)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'Delay: ',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          ToggleButtons(
                            isSelected: [
                              _delaySeconds == 5,
                              _delaySeconds == 10,
                            ],
                            onPressed: (index) {
                              setState(() {
                                _delaySeconds = index == 0 ? 5 : 10;
                              });
                            },

                            borderRadius: BorderRadius.circular(8),
                            selectedColor: Colors.white,
                            fillColor: Colors.indigo,
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('5s'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('10s'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Toggle button
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: ElevatedButton(
                      onPressed: _toggleOverlay,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: _isActive
                            ? Colors.red
                            : isCounting
                            ? Colors.orange
                            : Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isCounting) ...[
                            Text(
                              '$_countdown',
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'TAP TO CANCEL',
                              style: TextStyle(fontSize: 12),
                            ),
                          ] else ...[
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isCounting)
                    Text(
                      'Switch to your app now!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'U-shape swipe to unlock\n'
                      'Or tap emergency text 20x within 5 seconds',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white38),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class DeveloperInfoPage extends StatelessWidget {
  const DeveloperInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Developer')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 48,
                backgroundColor: Colors.indigo,
                child: Text(
                  'HU',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Henry Unegbu',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mobile & Web Developer',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white60),
              ),
              const SizedBox(height: 32),
              _DevContactTile(
                icon: Icons.email_outlined,
                label: 'ikennaunegbu10@gmail.com',
                onTap: () =>
                    launchUrl(Uri.parse('mailto:ikennaunegbu10@gmail.com')),
              ),
              const SizedBox(height: 12),
              _DevContactTile(
                icon: Icons.code,
                label: 'github.com/Henryikenna',
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/Henryikenna'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'Built with Flutter',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DevContactTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.indigo.shade200),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            const Icon(Icons.open_in_new, size: 18, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
