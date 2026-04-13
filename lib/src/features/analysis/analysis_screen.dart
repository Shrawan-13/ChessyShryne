import 'package:chessy_shryne/src/models.dart';
import 'package:chessy_shryne/src/pgn.dart';
import 'package:chessy_shryne/src/shared/widgets/metric_card.dart';
import 'package:chessy_shryne/src/shared/widgets/move_table.dart';
import 'package:flutter/material.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key, required this.game});

  final RecentGameSummary game;

  @override
  Widget build(BuildContext context) {
    final headers = parsePgnHeaders(game.pgn);
    final moves = parseMoveList(game.pgn);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Game Review'),
            actions: [
              IconButton(
                tooltip: 'Open source link',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Source link: ${game.url}')),
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Card(
                  color: scheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game.opening ?? headers['Opening'] ?? 'Game review',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${game.white.displayName} vs ${game.black.displayName}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text(game.source.label)),
                            Chip(label: Text(game.resultLabel)),
                            if (game.timeControl != null)
                              Chip(label: Text(game.timeControl!)),
                            Chip(label: Text(formatLongDate(game.playedAt))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Moves',
                        value: '${moves.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(label: 'Result', value: game.result),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Event',
                        value: game.event ?? headers['Event'] ?? 'Casual game',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        label: 'Site',
                        value:
                            game.site ?? headers['Site'] ?? game.source.label,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Move list',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Readable SAN notation for quick review.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        if (moves.isEmpty)
                          const Text('No moves available in this PGN.')
                        else
                          MoveTable(moves: moves),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
