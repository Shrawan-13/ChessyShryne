import 'dart:async';

import 'package:chessy_shryne/main.dart';
import 'package:chessy_shryne/src/features/analysis/game_analysis_service.dart';
import 'package:chessy_shryne/src/features/settings/settings_screen.dart';
import 'package:chessy_shryne/src/models.dart';
import 'package:chessy_shryne/src/preferences.dart';
import 'package:chessy_shryne/src/repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots into app shell and supports bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(
        repository: FakeGamesRepository(),
        preferencesStore: MemoryPreferencesStore(),
        analysisService: GameAnalysisService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chessy Shryne'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchBar), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Save preferences'), findsOneWidget);
  });

  testWidgets('settings save updates home behavior', (
    WidgetTester tester,
  ) async {
    final repository = FakeGamesRepository(
      gamesByUser: {
        'shrawan': [fakeGame(username: 'shrawan')],
      },
    );

    await tester.pumpWidget(
      MyApp(
        repository: repository,
        preferencesStore: MemoryPreferencesStore(),
        analysisService: GameAnalysisService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No username saved yet'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'shrawan');
    tester.testTextInput.closeConnection();
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    final saveButton = find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.widgetWithText(FilledButton, 'Save preferences'),
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('shrawan'), findsWidgets);
    expect(find.text('Sicilian Defense'), findsOneWidget);
  });

  testWidgets('search shows loading then results', (WidgetTester tester) async {
    final completer = Completer<List<RecentGameSummary>>();
    final repository = FakeGamesRepository.withResponder((username, source) {
      return completer.future;
    });

    await tester.pumpWidget(
      MyApp(
        repository: repository,
        preferencesStore: MemoryPreferencesStore(),
        analysisService: GameAnalysisService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'hikaru');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();

    expect(find.text('Searching recent games'), findsOneWidget);

    completer.complete([fakeGame(username: 'hikaru')]);
    await tester.pumpAndSettle();

    expect(find.text('Results for hikaru'), findsOneWidget);
    expect(find.text('Sicilian Defense'), findsOneWidget);
  });

  testWidgets('search shows error state on failure', (
    WidgetTester tester,
  ) async {
    final repository = FakeGamesRepository.withResponder((
      username,
      source,
    ) async {
      throw Exception('Network down');
    });

    await tester.pumpWidget(
      MyApp(
        repository: repository,
        preferencesStore: MemoryPreferencesStore(),
        analysisService: GameAnalysisService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'hikaru');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Search failed'), findsOneWidget);
    expect(find.text('Network down'), findsOneWidget);
  });
}

class FakeGamesRepository implements GamesRepository {
  FakeGamesRepository({Map<String, List<RecentGameSummary>>? gamesByUser})
    : _gamesByUser = gamesByUser ?? const {},
      _responder = null;

  FakeGamesRepository.withResponder(
    Future<List<RecentGameSummary>> Function(String, GameSource) responder,
  ) : _responder = responder,
      _gamesByUser = const {};

  final Map<String, List<RecentGameSummary>> _gamesByUser;
  final Future<List<RecentGameSummary>> Function(String, GameSource)?
  _responder;

  @override
  Future<List<RecentGameSummary>> fetchRecentGames(
    String username,
    GameSource source,
  ) async {
    if (_responder != null) {
      return _responder(username, source);
    }
    return _gamesByUser[username] ?? const [];
  }
}

RecentGameSummary fakeGame({required String username}) {
  return RecentGameSummary(
    id: '1',
    source: GameSource.lichess,
    pgn:
        '''
[Event "Rated Blitz game"]
[Site "https://lichess.org/abc123"]
[Date "2026.04.13"]
[White "$username"]
[Black "opponent"]
[Result "1-0"]
[Opening "Sicilian Defense"]

1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 *
''',
    white: PlayerSummary(name: username, rating: 1800),
    black: const PlayerSummary(name: 'opponent', rating: 1750),
    result: '1-0',
    playedAt: DateTime(2026, 4, 13),
    url: 'https://lichess.org/abc123',
    timeControl: '3+2',
    movesCount: 8,
    opening: 'Sicilian Defense',
    event: 'Rated Blitz game',
    site: 'https://lichess.org/abc123',
  );
}
