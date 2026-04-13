import 'package:chessy_shryne/src/app.dart';
import 'package:chessy_shryne/src/preferences.dart';
import 'package:chessy_shryne/src/repository.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    MyApp(
      repository: HttpGamesRepository(),
      preferencesStore: SharedPreferencesStore(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.repository,
    required this.preferencesStore,
  });

  final GamesRepository repository;
  final PreferencesStore preferencesStore;

  @override
  Widget build(BuildContext context) {
    return ChessyShryneApp(
      repository: repository,
      preferencesStore: preferencesStore,
    );
  }
}
