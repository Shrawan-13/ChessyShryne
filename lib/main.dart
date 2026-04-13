import 'package:chessy_shryne/src/app.dart';
import 'package:chessy_shryne/src/features/analysis/game_analysis_service.dart';
import 'package:chessy_shryne/src/preferences.dart';
import 'package:chessy_shryne/src/repository.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    MyApp(
      repository: HttpGamesRepository(),
      preferencesStore: SharedPreferencesStore(),
      analysisService: GameAnalysisService(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.repository,
    required this.preferencesStore,
    required this.analysisService,
  });

  final GamesRepository repository;
  final PreferencesStore preferencesStore;
  final GameAnalysisService analysisService;

  @override
  Widget build(BuildContext context) {
    return ChessyShryneApp(
      repository: repository,
      preferencesStore: preferencesStore,
      analysisService: analysisService,
    );
  }
}
