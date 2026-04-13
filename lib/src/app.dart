import 'package:chessy_shryne/src/models.dart';
import 'package:chessy_shryne/src/pgn.dart';
import 'package:chessy_shryne/src/preferences.dart';
import 'package:chessy_shryne/src/repository.dart';
import 'package:flutter/material.dart';

class ChessyShryneApp extends StatefulWidget {
  const ChessyShryneApp({
    super.key,
    required this.repository,
    required this.preferencesStore,
  });

  final GamesRepository repository;
  final PreferencesStore preferencesStore;

  @override
  State<ChessyShryneApp> createState() => _ChessyShryneAppState();
}

class _ChessyShryneAppState extends State<ChessyShryneApp> {
  late Future<UserPreferences> _preferencesFuture;

  @override
  void initState() {
    super.initState();
    _preferencesFuture = widget.preferencesStore.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chessy Shryne',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: FutureBuilder<UserPreferences>(
        future: _preferencesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _BootstrapScreen();
          }

          return _AppShell(
            repository: widget.repository,
            preferencesStore: widget.preferencesStore,
            initialPreferences: snapshot.data!,
          );
        },
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF8C4B2F),
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: Typography.material2021(platform: TargetPlatform.android).black,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(semanticsLabel: 'Loading app'),
            const SizedBox(height: 16),
            Text(
              'Preparing your chess review space',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell({
    required this.repository,
    required this.preferencesStore,
    required this.initialPreferences,
  });

  final GamesRepository repository;
  final PreferencesStore preferencesStore;
  final UserPreferences initialPreferences;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  late UserPreferences _preferences;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences;
  }

  Future<void> _savePreferences(UserPreferences preferences) async {
    await widget.preferencesStore.save(preferences);
    if (mounted) {
      setState(() {
        _preferences = preferences;
      });
    }
  }

  void _openAnalysis(RecentGameSummary game) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => AnalysisScreen(game: game)));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        preferences: _preferences,
        repository: widget.repository,
        onOpenSettings: () => setState(() => _selectedIndex = 2),
        onOpenAnalysis: _openAnalysis,
      ),
      SearchScreen(
        initialSource: _preferences.preferredSource,
        repository: widget.repository,
        onOpenAnalysis: _openAnalysis,
      ),
      SettingsScreen(preferences: _preferences, onSave: _savePreferences),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

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
      if (mounted) {
        setState(() {
          _games = const [];
          _errorMessage = null;
          _isLoading = false;
        });
      }
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
    final scheme = Theme.of(context).colorScheme;

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
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username == null || username.isEmpty
                            ? 'Build your personal review feed'
                            : 'Recent games for $username',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        username == null || username.isEmpty
                            ? 'Save your username once in Settings and the home screen becomes your daily chess review ritual.'
                            : 'A calmer home screen: your latest games, one tap away from review, with no extra choices to think through.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: username == null || username.isEmpty
                                ? widget.onOpenSettings
                                : () => _refreshIfNeeded(force: true),
                            icon: Icon(
                              username == null || username.isEmpty
                                  ? Icons.person_add_alt_1_rounded
                                  : Icons.sync_rounded,
                            ),
                            label: Text(
                              username == null || username.isEmpty
                                  ? 'Set my username'
                                  : 'Refresh home',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: widget.onOpenSettings,
                            icon: const Icon(Icons.tune_rounded),
                            label: const Text('Home settings'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
              ],
              if (username == null || username.isEmpty)
                _EmptyStateCard(
                  icon: Icons.manage_accounts_rounded,
                  title: 'No username saved yet',
                  message:
                      'Add your Lichess or Chess.com username in Settings and this screen will show your recent games automatically.',
                  actionLabel: 'Open settings',
                  onPressed: widget.onOpenSettings,
                )
              else if (_errorMessage != null)
                _EmptyStateCard(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load your recent games',
                  message: _errorMessage!,
                  actionLabel: 'Try again',
                  onPressed: () => _refreshIfNeeded(force: true),
                )
              else if (!_isLoading && _games.isEmpty)
                _EmptyStateCard(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'No recent games found',
                  message:
                      'Try switching the source in Settings or check that the username is correct.',
                  actionLabel: 'Adjust settings',
                  onPressed: widget.onOpenSettings,
                )
              else ...[
                _SectionHeader(
                  title: 'Your recent games',
                  subtitle:
                      '${widget.preferences.preferredSource.label} • ${_games.length} loaded',
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
                      Text(
                        'Search any player',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'One focused action: type a username, choose the source, and open a game for review.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
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
                _EmptyStateCard(
                  icon: Icons.search_off_rounded,
                  title: 'Search failed',
                  message: _errorMessage!,
                  actionLabel: 'Try again',
                  onPressed: _runSearch,
                )
              else if (_isLoading)
                const _LoadingStateCard(label: 'Searching recent games')
              else if (_lastSearch == null)
                const _EmptyStateCard(
                  icon: Icons.travel_explore_rounded,
                  title: 'Start with a username',
                  message:
                      'Search recent games from either platform and open one to review the PGN, move list, and metadata.',
                )
              else if (_results.isEmpty)
                _EmptyStateCard(
                  icon: Icons.inbox_outlined,
                  title: 'No recent games found',
                  message:
                      'No games were returned for $_lastSearch on ${_selectedSource.label}.',
                  actionLabel: 'Search again',
                  onPressed: _runSearch,
                )
              else ...[
                _SectionHeader(
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.preferences,
    required this.onSave,
  });

  final UserPreferences preferences;
  final Future<void> Function(UserPreferences preferences) onSave;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _usernameController;
  late GameSource _selectedSource;
  late bool _autoRefresh;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.preferences.username ?? '',
    );
    _selectedSource = widget.preferences.preferredSource;
    _autoRefresh = widget.preferences.autoRefreshHome;
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences != widget.preferences) {
      _usernameController.text = widget.preferences.username ?? '';
      _selectedSource = widget.preferences.preferredSource;
      _autoRefresh = widget.preferences.autoRefreshHome;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
    });

    final trimmed = _usernameController.text.trim();
    final preferences = widget.preferences.copyWith(
      username: trimmed,
      clearUsername: trimmed.isEmpty,
      preferredSource: _selectedSource,
      autoRefreshHome: _autoRefresh,
    );

    await widget.onSave(preferences);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(title: Text('Settings')),
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
                      Text(
                        'Make home feel personal',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Save your own username once so the app opens into your recent games instead of asking you what to do every time.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Your username',
                          hintText: 'e.g. Hikaru or DrNykterstein',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Default source',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<GameSource>(
                        segments: GameSource.values
                            .map(
                              (source) => ButtonSegment<GameSource>(
                                value: source,
                                label: Text(source.label),
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
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _autoRefresh,
                        onChanged: (value) {
                          setState(() {
                            _autoRefresh = value;
                          });
                        },
                        title: const Text('Refresh home automatically'),
                        subtitle: const Text(
                          'Load your recent games when the app opens and when your saved identity changes.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _handleSave,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save preferences'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

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
                  color: scheme.secondaryContainer,
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
                        const SizedBox(height: 16),
                        Text(
                          'This first version focuses on rapid comprehension: who played, what happened, when it happened, and the full move sequence with minimal friction.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Moves',
                        value: '${moves.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(label: 'Result', value: game.result),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Event',
                        value: game.event ?? headers['Event'] ?? 'Casual game',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < moves.length; i++)
                                _MoveChip(turnIndex: i, move: moves[i]),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: const Icon(Icons.psychology_alt_outlined),
                    title: const Text('Next analysis layer'),
                    subtitle: const Text(
                      'Engine evaluation, mistakes, and position scoring can plug into this screen later without changing the flow.',
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  const _MoveChip({required this.turnIndex, required this.move});

  final int turnIndex;
  final String move;

  @override
  Widget build(BuildContext context) {
    final turnNumber = (turnIndex ~/ 2) + 1;
    final prefix = turnIndex.isEven ? '$turnNumber.' : '$turnNumber...';

    return Chip(label: Text('$prefix $move'));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (actionLabel != null && onPressed != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onPressed, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingStateCard extends StatelessWidget {
  const _LoadingStateCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
