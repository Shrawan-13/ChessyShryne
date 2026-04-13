import 'package:chessy_shryne/src/models.dart';
import 'package:chessy_shryne/src/pgn.dart';
import 'package:flutter/material.dart';

class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.perspectiveUsername,
  });

  final RecentGameSummary game;
  final VoidCallback onTap;
  final String? perspectiveUsername;

  @override
  Widget build(BuildContext context) {
    final username = perspectiveUsername?.trim();
    final subtitle = username == null || username.isEmpty
        ? '${game.white.displayName} vs ${game.black.displayName}'
        : '${game.opponentOf(username)} • ${game.userPlayedWhite(username) ? 'You had White' : 'You had Black'}';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(child: Text(game.source.shortLabel)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game.opening ?? game.resultLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(game.result)),
                  Chip(label: Text(formatRelativeDay(game.playedAt))),
                  if (game.timeControl != null)
                    Chip(label: Text(game.timeControl!)),
                  if (game.movesCount != null)
                    Chip(label: Text('${game.movesCount} moves')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
