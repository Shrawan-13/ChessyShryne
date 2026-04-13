import 'package:chessy_shryne/src/features/analysis/analysis_screen.dart';
import 'package:chessy_shryne/src/features/analysis/game_analysis_service.dart';
import 'package:chessy_shryne/src/features/home/home_screen.dart';
import 'package:chessy_shryne/src/features/search/search_screen.dart';
import 'package:chessy_shryne/src/features/settings/settings_screen.dart';
import 'package:chessy_shryne/src/models.dart';
import 'package:chessy_shryne/src/preferences.dart';
import 'package:chessy_shryne/src/repository.dart';
import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.repository,
    required this.preferencesStore,
    required this.analysisService,
    required this.initialPreferences,
  });

  final GamesRepository repository;
  final PreferencesStore preferencesStore;
  final GameAnalysisService analysisService;
  final UserPreferences initialPreferences;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late UserPreferences _preferences;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences;
  }

  Future<void> _savePreferences(UserPreferences preferences) async {
    await widget.preferencesStore.save(preferences);
    if (!mounted) {
      return;
    }

    setState(() {
      _preferences = preferences;
    });
  }

  void _openAnalysis(RecentGameSummary game) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnalysisScreen(
          game: game,
          analysisService: widget.analysisService,
          preset: _preferences.analysisPreset,
        ),
      ),
    );
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
