import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/game_registry.dart';
import '../../core/game_module.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final games = GameRegistry.instance.games;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: games.isEmpty
          ? const Center(child: Text('Chưa có game nào'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              itemCount: games.length,
              itemBuilder: (context, i) => _GameCard(game: games[i]),
            ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});
  final GameModule game;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/${game.id}'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            game.buildIcon(context),
            const SizedBox(height: 12),
            Text(
              _localizedName(context, game.nameKey),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _localizedName(context, game.descriptionKey),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.outline,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _localizedName(BuildContext context, String key) {
    // Fallback: return the key itself if no i18n lookup.
    // When ARB generation works, replace with AppLocalizations.of(context)!.{key}.
    final map = {
      'gameCaroName': 'Cờ Caro',
      'gameCaroDescription': 'Cờ caro luật Việt Nam',
      'gameBidaName': 'Bida',
      'gameBidaDescription': 'Pool 8-ball, 9-ball, Bida VN, Carom 3 băng',
      'gameSudokuName': 'Sudoku',
      'gameSudokuDescription': 'Classic, Killer, X-Sudoku — 4 cấp độ',
    };
    return map[key] ?? key;
  }
}
