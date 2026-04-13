import 'package:chessy_shryne/src/models.dart';
import 'package:chessy_shryne/src/repository.dart';
import 'package:chessy_shryne/src/shared/widgets/empty_state_card.dart';
import 'package:chessy_shryne/src/shared/widgets/game_card.dart';
import 'package:chessy_shryne/src/shared/widgets/loading_state_card.dart';
import 'package:chessy_shryne/src/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.initialSource,
    required this.repository,
    required this.onOpenAnalysis,
  });

  final GameSource initialSource;
  final GamesRepository repository;
  final ValueChanged<RecentGameSummary> onOpenAnalysis;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late GameSource _selectedSource;
  bool _isLoading = false;
  String? _errorMessage;
  List<RecentGameSummary> _results = const [];
  String? _lastSearch;

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.initialSource;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final username = _controller.text.trim();
    FocusScope.of(context).unfocus();

    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a username to search recent games.';
        _results = const [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _lastSearch = username;
    });

    try {
      final games = await widget.repository.fetchRecentGames(
        username,
        _selectedSource,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _results = games;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _results = const [];
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(title: Text('Search')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SearchBar(
                        controller: _controller,
                        focusNode: _focusNode,
                        hintText: 'Search username',
                        leading: const Icon(Icons.search_rounded),
                        trailing: [
                          IconButton(
                            tooltip: 'Run search',
                            onPressed: _isLoading ? null : _runSearch,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ],
                        onSubmitted: (_) => _runSearch(),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<GameSource>(
                        segments: GameSource.values
                            .map(
                              (source) => ButtonSegment<GameSource>(
                                value: source,
                                label: Text(source.label),
                                icon: CircleAvatar(
                                  radius: 10,
                                  child: Text(source.shortLabel),
                                ),
                              ),
                            )
                            .toList(),
                        selected: {_selectedSource},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _selectedSource = selection.first;
                          });
                        },
                      ),
                      if (_isLoading) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null)
                EmptyStateCard(
                  icon: Icons.search_off_rounded,
                  title: 'Search failed',
                  message: _errorMessage!,
                  actionLabel: 'Try again',
                  onPressed: _runSearch,
                )
              else if (_isLoading)
                const LoadingStateCard(label: 'Searching recent games')
              else if (_lastSearch == null)
                const EmptyStateCard(
                  icon: Icons.travel_explore_rounded,
                  title: 'Start with a username',
                  message:
                      'Search recent games from either platform and open one to review the PGN, move list, and metadata.',
                )
              else if (_results.isEmpty)
                EmptyStateCard(
                  icon: Icons.inbox_outlined,
                  title: 'No recent games found',
                  message:
                      'No games were returned for $_lastSearch on ${_selectedSource.label}.',
                  actionLabel: 'Search again',
                  onPressed: _runSearch,
                )
              else ...[
                SectionHeader(
                  title: 'Results for $_lastSearch',
                  subtitle:
                      '${_selectedSource.label} • ${_results.length} games',
                ),
                const SizedBox(height: 12),
                ..._results.map(
                  (game) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GameCard(
                      game: game,
                      perspectiveUsername: _lastSearch,
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
