import 'package:chessy_shryne/src/app/app_shell.dart';
import 'package:chessy_shryne/src/features/analysis/game_analysis_service.dart';
import 'package:chessy_shryne/src/models.dart';
import 'package:chessy_shryne/src/preferences.dart';
import 'package:chessy_shryne/src/repository.dart';
import 'package:chessy_shryne/src/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ChessyShryneApp extends StatefulWidget {
  const ChessyShryneApp({
    super.key,
    required this.repository,
    required this.preferencesStore,
    required this.analysisService,
  });

  final GamesRepository repository;
  final PreferencesStore preferencesStore;
  final GameAnalysisService analysisService;

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
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: FutureBuilder<UserPreferences>(
        future: _preferencesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _BootstrapScreen();
          }

          return AppShell(
            repository: widget.repository,
            preferencesStore: widget.preferencesStore,
            analysisService: widget.analysisService,
            initialPreferences: snapshot.data!,
          );
        },
      ),
    );
  }
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
            const CircularProgressIndicator(semanticsLabel: 'Loading app'),
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
