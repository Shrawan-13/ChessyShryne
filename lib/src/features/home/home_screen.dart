import 'package:chessy_shryne/src/models.dart';
import 'package:chessy_shryne/src/repository.dart';
import 'package:chessy_shryne/src/shared/widgets/empty_state_card.dart';
import 'package:chessy_shryne/src/shared/widgets/game_card.dart';
import 'package:chessy_shryne/src/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.preferences,
    required this.repository,
    required this.onOpenSettings,
    required this.onOpenAnalysis,
  });

  final UserPreferences preferences;
  final GamesRepository repository;
  final VoidCallback onOpenSettings;
  final ValueChanged<RecentGameSummary> onOpenAnalysis;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<RecentGameSummary> _games = const [];

  @override
  void initState() {
    super.initState();
    _refreshIfNeeded(force: true);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences.username != widget.preferences.username ||
        oldWidget.preferences.preferredSource !=
            widget.preferences.preferredSource ||
        oldWidget.preferences.autoRefreshHome !=
            widget.preferences.autoRefreshHome) {
      _refreshIfNeeded(force: widget.preferences.autoRefreshHome);
    }
  }

  Future<void> _refreshIfNeeded({bool force = false}) async {
    final username = widget.preferences.username?.trim();
    if (username == null || username.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _games = const [];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    if (!force && _games.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final games = await widget.repository.fetchRecentGames(
        username,
        widget.preferences.preferredSource,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _games = games;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.preferences.username?.trim();

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('Chessy Shryne'),
          actions: [
            IconButton(
              onPressed: _isLoading
                  ? null
                  : () => _refreshIfNeeded(force: true),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh games',
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (_isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
              ],
              if (username == null || username.isEmpty)
                EmptyStateCard(
                  icon: Icons.manage_accounts_rounded,
                  title: 'No username saved yet',
                  message:
                      'Add your Lichess or Chess.com username in Settings and this screen will show your recent games automatically.',
                  actionLabel: 'Open settings',
                  onPressed: widget.onOpenSettings,
                )
              else if (_errorMessage != null)
                EmptyStateCard(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load your recent games',
                  message: _errorMessage!,
                  actionLabel: 'Try again',
                  onPressed: () => _refreshIfNeeded(force: true),
                )
              else if (!_isLoading && _games.isEmpty)
                EmptyStateCard(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'No recent games found',
                  message:
                      'Try switching the source in Settings or check that the username is correct.',
                  actionLabel: 'Adjust settings',
                  onPressed: widget.onOpenSettings,
                )
              else ...[
                SectionHeader(
                  title: username,
                  subtitle:
                      '${widget.preferences.preferredSource.label} • ${_games.length} loaded',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _refreshIfNeeded(force: true),
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Refresh'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onOpenSettings,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Settings'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._games.map(
                  (game) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GameCard(
                      game: game,
                      perspectiveUsername: username,
                      onTap: () => widget.onOpenAnalysis(game),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}
