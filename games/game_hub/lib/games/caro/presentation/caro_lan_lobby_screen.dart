import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../network/lan_client.dart';
import '../network/lan_host.dart';
import '../../../core/storage/settings_service.dart';
import 'caro_game_notifier.dart';

/// Screen shown when the current device is hosting a LAN game.
class CaroLanHostScreen extends ConsumerStatefulWidget {
  const CaroLanHostScreen({super.key});

  @override
  ConsumerState<CaroLanHostScreen> createState() => _CaroLanHostScreenState();
}

class _CaroLanHostScreenState extends ConsumerState<CaroLanHostScreen> {
  String? _localIp;
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _loadIp();
    // Listen for client connection.
    final host = ref.read(caroGameProvider).lanHost;
    if (host != null) {
      _sub = host.onPacket.listen((_) {
        // Once a packet arrives (after welcome), game is ready.
        if (host.state == HostState.playing && mounted) {
          context.pushReplacement('/caro/game');
        }
      });
    } else {
      _sub = const Stream.empty().listen((_) {});
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _loadIp() async {
    final ip = await NetworkInfo().getWifiIP();
    if (mounted) setState(() => _localIp = ip);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(caroGameProvider);
    final host = state.lanHost;
    final port = host?.port ?? 0;
    final qrData = 'caro://$_localIp:$port';

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo phòng LAN')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text('Đang chờ đối thủ kết nối...'),
              const SizedBox(height: 24),
              if (_localIp != null) ...[
                Text('IP của bạn: $_localIp',
                    style: Theme.of(context).textTheme.bodyLarge),
                Text('Cổng: $port',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: '$_localIp:$port'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã sao chép IP:Port')),
                    );
                  },
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Bấm vào QR để sao chép địa chỉ',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen shown when joining a LAN game as client.
class CaroLanJoinScreen extends ConsumerStatefulWidget {
  const CaroLanJoinScreen({super.key});

  @override
  ConsumerState<CaroLanJoinScreen> createState() => _CaroLanJoinScreenState();
}

class _CaroLanJoinScreenState extends ConsumerState<CaroLanJoinScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vào phòng LAN')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ IP',
                hintText: '192.168.1.x',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Cổng (Port)',
                hintText: '4xxxx',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _connecting ? null : _connect,
              child: _connecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Kết nối'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connect() async {
    final ip = _ipController.text.trim();
    final portStr = _portController.text.trim();
    if (ip.isEmpty || portStr.isEmpty) {
      setState(() => _error = 'Vui lòng nhập đầy đủ IP và Port');
      return;
    }
    final port = int.tryParse(portStr);
    if (port == null) {
      setState(() => _error = 'Port không hợp lệ');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      final settings = SettingsService.instance;
      final client = LanClient(playerName: settings.playerName);
      await client.connect(ip, port);

      // Wait for welcome packet.
      await client.onPacket
          .firstWhere((p) => true)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      ref
          .read(caroGameProvider.notifier)
          .startLanClient(playerName: settings.playerName, client: client);
      context.pushReplacement('/caro/game');
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = 'Không thể kết nối: $e';
        });
      }
    }
  }
}
