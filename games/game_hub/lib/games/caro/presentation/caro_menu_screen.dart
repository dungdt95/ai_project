import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/storage/settings_service.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/move.dart';
import 'caro_game_notifier.dart';
import '../network/lan_host.dart';

class CaroMenuScreen extends ConsumerStatefulWidget {
  const CaroMenuScreen({super.key});

  @override
  ConsumerState<CaroMenuScreen> createState() => _CaroMenuScreenState();
}

class _CaroMenuScreenState extends ConsumerState<CaroMenuScreen> {
  AiDifficulty _difficulty = AiDifficulty.medium;
  _SideChoice _sideChoice = _SideChoice.random;

  final _settings = SettingsService.instance;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cờ Caro')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _SectionTitle('Chơi với máy'),
          const SizedBox(height: 12),
          _DifficultySelector(
            selected: _difficulty,
            onChanged: (d) => setState(() => _difficulty = d),
          ),
          const SizedBox(height: 12),
          _SideSelector(
            selected: _sideChoice,
            onChanged: (s) => setState(() => _sideChoice = s),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Bắt đầu vs Máy',
            icon: Icons.smart_toy_outlined,
            onPressed: () => _startVsAi(context),
          ),
          const SizedBox(height: 32),
          _SectionTitle('Chơi với người'),
          const SizedBox(height: 12),
          AppButton(
            label: 'Chơi cùng máy (2 người)',
            icon: Icons.people_outline,
            onPressed: () => _startLocal(context),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Tạo phòng LAN',
            icon: Icons.wifi,
            onPressed: () => _createLan(context),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Vào phòng LAN',
            icon: Icons.wifi_find,
            onPressed: () => context.push('/caro/lan/join'),
          ),
          const SizedBox(height: 32),
          _SectionTitle('Khác'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/caro/history'),
                icon: const Icon(Icons.history),
                label: const Text('Lịch sử'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/caro/stats'),
                icon: const Icon(Icons.bar_chart),
                label: const Text('Thống kê'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _startVsAi(BuildContext context) {
    final side = _sideChoice == _SideChoice.random
        ? (Random().nextBool() ? Player.x : Player.o)
        : (_sideChoice == _SideChoice.x ? Player.x : Player.o);
    ref.read(caroGameProvider.notifier).startVsAi(
          playerName: _settings.playerName,
          difficulty: _difficulty,
          humanSide: side,
        );
    context.push('/caro/game');
  }

  void _startLocal(BuildContext context) {
    ref.read(caroGameProvider.notifier).startLocal(
          playerXName: _settings.playerName,
          playerOName: 'Player 2',
        );
    context.push('/caro/game');
  }

  Future<void> _createLan(BuildContext context) async {
    final host = LanHost(hostName: _settings.playerName, boardSize: 15);
    await host.start();
    if (!context.mounted) return;
    ref.read(caroGameProvider.notifier).startLanHost(
          hostName: _settings.playerName,
          host: host,
        );
    context.push('/caro/lan/host');
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      );
}

enum _SideChoice { x, o, random }

class _DifficultySelector extends StatelessWidget {
  const _DifficultySelector({required this.selected, required this.onChanged});
  final AiDifficulty selected;
  final ValueChanged<AiDifficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {
      AiDifficulty.easy: 'Dễ',
      AiDifficulty.medium: 'Vừa',
      AiDifficulty.hard: 'Khó',
      AiDifficulty.superHard: 'Siêu khó',
    };
    return Wrap(
      spacing: 8,
      children: AiDifficulty.values.map((d) {
        final sel = selected == d;
        return ChoiceChip(
          label: Text(labels[d]!),
          selected: sel,
          onSelected: (_) => onChanged(d),
        );
      }).toList(),
    );
  }
}

class _SideSelector extends StatelessWidget {
  const _SideSelector({required this.selected, required this.onChanged});
  final _SideChoice selected;
  final ValueChanged<_SideChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Quân X (đi trước)'),
          selected: selected == _SideChoice.x,
          onSelected: (_) => onChanged(_SideChoice.x),
        ),
        ChoiceChip(
          label: const Text('Quân O (đi sau)'),
          selected: selected == _SideChoice.o,
          onSelected: (_) => onChanged(_SideChoice.o),
        ),
        ChoiceChip(
          label: const Text('Ngẫu nhiên'),
          selected: selected == _SideChoice.random,
          onSelected: (_) => onChanged(_SideChoice.random),
        ),
      ],
    );
  }
}
