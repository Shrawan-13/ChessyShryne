import 'dart:convert';

import 'package:chessy_shryne/src/models.dart';
import 'package:chessy_shryne/src/pgn.dart';
import 'package:http/http.dart' as http;

abstract class GamesRepository {
  Future<List<RecentGameSummary>> fetchRecentGames(
    String username,
    GameSource source,
  );
}

class HttpGamesRepository implements GamesRepository {
  HttpGamesRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<List<RecentGameSummary>> fetchRecentGames(
    String username,
    GameSource source,
  ) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    switch (source) {
      case GameSource.lichess:
        return _fetchLichessGames(trimmed);
      case GameSource.chessCom:
        return _fetchChessComGames(trimmed);
    }
  }

  Future<List<RecentGameSummary>> _fetchLichessGames(String username) async {
    final response = await _client.get(
      Uri.parse(
        'https://lichess.org/api/games/user/${Uri.encodeComponent(username)}'
        '?max=20&pgnInJson=true&sort=dateDesc&clocks=true&opening=true',
      ),
      headers: const {'accept': 'application/x-ndjson'},
    );

    if (response.statusCode >= 400) {
      throw Exception('Unable to fetch recent games from Lichess.');
    }

    final lines = response.body
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);

    final games = <RecentGameSummary>[];
    for (final line in lines) {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final players = json['players'] as Map<String, dynamic>? ?? {};
      final white = players['white'] as Map<String, dynamic>? ?? {};
      final black = players['black'] as Map<String, dynamic>? ?? {};
      final clock = json['clock'] as Map<String, dynamic>? ?? {};
      final opening = json['opening'] as Map<String, dynamic>? ?? {};
      final pgn = (json['pgn'] as String?) ?? '';

      games.add(
        RecentGameSummary(
          id: (json['id'] as String?) ?? pgn.hashCode.toString(),
          source: GameSource.lichess,
          pgn: pgn,
          white: PlayerSummary(
            name:
                ((white['user'] as Map<String, dynamic>?)?['name']
                    as String?) ??
                'White',
            rating: white['rating'] as int?,
            title:
                ((white['user'] as Map<String, dynamic>?)?['title'] as String?),
          ),
          black: PlayerSummary(
            name:
                ((black['user'] as Map<String, dynamic>?)?['name']
                    as String?) ??
                'Black',
            rating: black['rating'] as int?,
            title:
                ((black['user'] as Map<String, dynamic>?)?['title'] as String?),
          ),
          result: _resultFromLichess(json),
          playedAt: DateTime.fromMillisecondsSinceEpoch(
            (json['createdAt'] as int?) ?? 0,
          ),
          url: 'https://lichess.org/${json['id']}',
          timeControl: _formatLichessTimeControl(clock),
          movesCount: ((json['moves'] as String?) ?? '')
              .split(' ')
              .where((move) => move.isNotEmpty)
              .length,
          opening:
              opening['name'] as String? ?? parsePgnHeaders(pgn)['Opening'],
          event: parsePgnHeaders(pgn)['Event'],
          site: parsePgnHeaders(pgn)['Site'],
        ),
      );
    }

    return games;
  }

  Future<List<RecentGameSummary>> _fetchChessComGames(String username) async {
    final now = DateTime.now().toUtc();
    final responses = <http.Response>[];

    responses.add(await _fetchChessComMonth(username, now.year, now.month));
    if (_readChessComGames(responses.first).length < 20) {
      final previousMonth = now.month == 1 ? 12 : now.month - 1;
      final previousYear = now.month == 1 ? now.year - 1 : now.year;
      responses.add(
        await _fetchChessComMonth(username, previousYear, previousMonth),
      );
    }

    final games =
        responses
            .expand(_readChessComGames)
            .where((game) => (game['pgn'] as String?)?.isNotEmpty ?? false)
            .toList()
          ..sort(
            (a, b) => ((b['end_time'] as int?) ?? 0).compareTo(
              (a['end_time'] as int?) ?? 0,
            ),
          );

    return games.take(20).map(_mapChessComGame).toList();
  }

  Future<http.Response> _fetchChessComMonth(
    String username,
    int year,
    int month,
  ) async {
    final monthString = month.toString().padLeft(2, '0');
    final response = await _client.get(
      Uri.parse(
        'https://api.chess.com/pub/player/'
        '${Uri.encodeComponent(username.toLowerCase())}/games/$year/$monthString',
      ),
    );

    if (response.statusCode >= 400) {
      throw Exception('Unable to fetch recent games from Chess.com.');
    }
    return response;
  }

  Iterable<Map<String, dynamic>> _readChessComGames(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final games = decoded['games'] as List<dynamic>? ?? const [];
    return games.cast<Map<String, dynamic>>();
  }

  RecentGameSummary _mapChessComGame(Map<String, dynamic> game) {
    final pgn = (game['pgn'] as String?) ?? '';
    final headers = parsePgnHeaders(pgn);
    final white = game['white'] as Map<String, dynamic>? ?? {};
    final black = game['black'] as Map<String, dynamic>? ?? {};

    return RecentGameSummary(
      id:
          (game['uuid'] as String?) ??
          (game['url'] as String?) ??
          pgn.hashCode.toString(),
      source: GameSource.chessCom,
      pgn: pgn,
      white: PlayerSummary(
        name: (white['username'] as String?) ?? 'White',
        rating: white['rating'] as int?,
        title: white['title'] as String?,
      ),
      black: PlayerSummary(
        name: (black['username'] as String?) ?? 'Black',
        rating: black['rating'] as int?,
        title: black['title'] as String?,
      ),
      result: headers['Result'] ?? '*',
      playedAt: DateTime.fromMillisecondsSinceEpoch(
        ((game['end_time'] as int?) ?? 0) * 1000,
      ),
      url: (game['url'] as String?) ?? '',
      timeControl: _formatChessComTimeControl(
        (game['time_control'] as String?) ?? '',
      ),
      movesCount: parseMoveList(pgn).length,
      opening: headers['Opening'],
      event: headers['Event'],
      site: headers['Site'],
    );
  }
}

String _resultFromLichess(Map<String, dynamic> json) {
  if (json['winner'] == 'white') {
    return '1-0';
  }
  if (json['winner'] == 'black') {
    return '0-1';
  }
  if (json['status'] == 'draw') {
    return '1/2-1/2';
  }
  return '*';
}

String? _formatLichessTimeControl(Map<String, dynamic> clock) {
  final initial = clock['initial'] as int?;
  final increment = clock['increment'] as int?;
  if (initial == null || increment == null) {
    return null;
  }
  return '${(initial / 60).floor()}+$increment';
}

String? _formatChessComTimeControl(String raw) {
  if (raw.isEmpty) {
    return null;
  }

  final parts = raw.split('+');
  final base = int.tryParse(parts.first);
  if (base == null) {
    return raw;
  }
  final increment = parts.length > 1 ? '+${parts[1]}' : '';

  if (base < 60) {
    return '${base}s$increment';
  }
  if (base < 3600) {
    final minutes = base ~/ 60;
    final seconds = base % 60;
    if (seconds == 0) {
      return '${minutes}m$increment';
    }
    return '${minutes}m${seconds.toString().padLeft(2, '0')}s$increment';
  }

  final hours = base ~/ 3600;
  final minutes = (base % 3600) ~/ 60;
  if (minutes == 0) {
    return '${hours}h$increment';
  }
  return '${hours}h${minutes.toString().padLeft(2, '0')}m$increment';
}
