import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:chess/chess.dart' as chess;
import 'package:chessy_shryne/src/features/analysis/analysis_models.dart';
import 'package:chessy_shryne/src/models.dart';
import 'package:chessy_shryne/src/pgn.dart';
import 'package:stockfish/stockfish.dart';

class GameAnalysisService {
  GameAnalysisService();

  final Map<String, Future<_EngineEval?>> _evalCache = {};
  Future<void> _engineQueue = Future<void>.value();
  Future<Stockfish>? _engineFuture;
  AnalysisPreset? _configuredPreset;

  Future<GameAnalysisData> analyzeGame(
    RecentGameSummary game,
    AnalysisPreset preset,
  ) {
    return _runExclusive(() async {
      final headers = parsePgnHeaders(game.pgn);
      final sanMoves = parseMoveList(game.pgn);
      final board = headers['FEN'] != null
          ? chess.Chess.fromFEN(headers['FEN']!)
          : chess.Chess();
      final initialFen = board.fen;

      final reconstructedMoves = <_ReconstructedMove>[];
      for (var index = 0; index < sanMoves.length; index++) {
        final san = sanMoves[index];
        final legalMoves = board.moves({'verbose': true}).cast<Map>();
        final matching = legalMoves.cast<Map<String, dynamic>>().firstWhere(
          (move) => _normalizeSan(move['san'] as String) == _normalizeSan(san),
          orElse: () => <String, dynamic>{},
        );

        if (matching.isEmpty) {
          continue;
        }

        final from = matching['from'] as String;
        final to = matching['to'] as String;
        final promotionSuffix = _promotionSuffix(san);
        final moved = board.move({
          'from': from,
          'to': to,
          ...?promotionSuffix == null ? null : {'promotion': promotionSuffix},
        });

        if (!moved) {
          continue;
        }

        reconstructedMoves.add(
          _ReconstructedMove(
            ply: index + 1,
            san: san,
            color: index.isEven ? 'white' : 'black',
            from: from,
            to: to,
            uci: '$from$to${promotionSuffix ?? ''}',
            fenBefore: reconstructedMoves.isEmpty
                ? initialFen
                : reconstructedMoves.last.fenAfter,
            fenAfter: board.fen,
          ),
        );
      }

      final uniqueFens = <String>{
        initialFen,
        ...reconstructedMoves.map((m) => m.fenAfter),
      };
      await Future.wait(uniqueFens.map((fen) => _fetchEval(fen, preset)));

      final analyzedMoves = <AnalyzedMove>[];
      for (var i = 0; i < reconstructedMoves.length; i++) {
        final move = reconstructedMoves[i];
        final previous = await _evalCache[_cacheKey(move.fenBefore, preset)];
        final next = await _evalCache[_cacheKey(move.fenAfter, preset)];
        analyzedMoves.add(
          AnalyzedMove(
            ply: move.ply,
            san: move.san,
            color: move.color,
            from: move.from,
            to: move.to,
            uci: move.uci,
            fenAfter: move.fenAfter,
            bestMove: previous?.bestMove,
            quality: _classifyMove(
              playedUci: move.uci,
              moverColor: move.color,
              previousEval: previous,
              nextEval: next,
            ),
          ),
        );
      }

      return GameAnalysisData(
        initialFen: initialFen,
        moves: analyzedMoves,
        whiteSummary: MoveQualitySummary.fromMoves(analyzedMoves, 'white'),
        blackSummary: MoveQualitySummary.fromMoves(analyzedMoves, 'black'),
      );
    });
  }

  Future<T> _runExclusive<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _engineQueue = _engineQueue.then((_) async {
      try {
        completer.complete(await task());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<_EngineEval?> _fetchEval(String fen, AnalysisPreset preset) {
    return _evalCache.putIfAbsent(_cacheKey(fen, preset), () async {
      final engine = await _ensureEngine();
      await _configureEngine(engine, preset);
      return _evaluateFen(engine, fen, preset);
    });
  }

  Future<Stockfish> _ensureEngine() {
    _engineFuture ??= () async {
      final engine = await stockfishAsync();
      await _waitForReady(
        engine,
        setup: () {
          engine.stdin = 'uci';
        },
      );
      await _waitForReady(
        engine,
        setup: () {
          engine.stdin = 'setoption name UCI_AnalyseMode value true';
        },
      );
      return engine;
    }();

    return _engineFuture!;
  }

  Future<void> _configureEngine(Stockfish engine, AnalysisPreset preset) async {
    if (_configuredPreset == preset) {
      return;
    }

    final config = _configForPreset(preset);
    await _waitForReady(
      engine,
      setup: () {
        engine.stdin = 'setoption name Threads value ${config.threads}';
        engine.stdin = 'setoption name Hash value ${config.hashMb}';
        engine.stdin = 'setoption name MultiPV value ${config.multiPv}';
      },
    );

    _configuredPreset = preset;
  }

  Future<_EngineEval?> _evaluateFen(
    Stockfish engine,
    String fen,
    AnalysisPreset preset,
  ) async {
    final config = _configForPreset(preset);
    final sideToMove = fen.split(' ')[1] == 'w' ? 'white' : 'black';
    final completer = Completer<_EngineEval?>();
    final infoByPv = <int, _RawEngineLine>{};
    late final StreamSubscription<String> subscription;

    subscription = engine.stdout.listen((line) {
      if (line.startsWith('info ')) {
        final parsed = _parseInfoLine(line);
        if (parsed != null) {
          infoByPv[parsed.multiPv] = parsed;
        }
        return;
      }

      if (line.startsWith('bestmove ')) {
        subscription.cancel();
        if (infoByPv.isEmpty) {
          completer.complete(null);
          return;
        }

        final primary = infoByPv[1];
        if (primary == null) {
          completer.complete(null);
          return;
        }

        final alternate = infoByPv[2];
        completer.complete(
          _EngineEval(
            bestMove: primary.pvMoves.isEmpty ? null : primary.pvMoves.first,
            whiteWinPercent: _whiteWinPercent(
              cp: primary.cp,
              mate: primary.mate,
              sideToMove: sideToMove,
            ),
            alternateWhiteWinPercent: alternate == null
                ? null
                : _whiteWinPercent(
                    cp: alternate.cp,
                    mate: alternate.mate,
                    sideToMove: sideToMove,
                  ),
          ),
        );
      }
    });

    engine.stdin = 'position fen $fen';
    engine.stdin = 'go depth ${config.depth}';

    return completer.future.timeout(
      const Duration(seconds: 25),
      onTimeout: () async {
        await subscription.cancel();
        engine.stdin = 'stop';
        return null;
      },
    );
  }

  Future<void> _waitForReady(
    Stockfish engine, {
    required void Function() setup,
  }) async {
    final completer = Completer<void>();
    late final StreamSubscription<String> subscription;

    subscription = engine.stdout.listen((line) {
      if (line.trim() == 'readyok' && !completer.isCompleted) {
        subscription.cancel();
        completer.complete();
      }
    });

    setup();
    engine.stdin = 'isready';
    await completer.future.timeout(const Duration(seconds: 10));
  }

  MoveQuality _classifyMove({
    required String playedUci,
    required String moverColor,
    required _EngineEval? previousEval,
    required _EngineEval? nextEval,
  }) {
    if (previousEval == null || nextEval == null) {
      return MoveQuality.good;
    }

    final before = previousEval.whiteWinPercent;
    final after = nextEval.whiteWinPercent;
    final orientedDelta = moverColor == 'white'
        ? after - before
        : before - after;
    final alternateGap = previousEval.alternateWhiteWinPercent == null
        ? 0.0
        : moverColor == 'white'
        ? after - previousEval.alternateWhiteWinPercent!
        : previousEval.alternateWhiteWinPercent! - after;

    final isBestMove = previousEval.bestMove == playedUci;
    if (isBestMove && orientedDelta >= 6 && alternateGap >= 16) {
      return MoveQuality.brilliant;
    }
    if (isBestMove && orientedDelta >= 3 && alternateGap >= 10) {
      return MoveQuality.great;
    }
    if (isBestMove) {
      return MoveQuality.best;
    }
    if (orientedDelta >= 1.5) {
      return MoveQuality.excellent;
    }
    if (orientedDelta >= -1.0) {
      return MoveQuality.good;
    }
    if (orientedDelta >= -5.0) {
      return MoveQuality.inaccuracy;
    }
    if (orientedDelta >= -12.0) {
      return MoveQuality.mistake;
    }
    return MoveQuality.blunder;
  }
}

_EngineConfig _configForPreset(AnalysisPreset preset) {
  final processors = math.max(1, Platform.numberOfProcessors);
  switch (preset) {
    case AnalysisPreset.low:
      return const _EngineConfig(depth: 10, multiPv: 2, threads: 1, hashMb: 16);
    case AnalysisPreset.medium:
      return _EngineConfig(
        depth: 14,
        multiPv: 2,
        threads: math.min(2, processors),
        hashMb: 32,
      );
    case AnalysisPreset.best:
      return _EngineConfig(
        depth: 18,
        multiPv: 2,
        threads: math.min(4, processors),
        hashMb: 64,
      );
  }
}

String _cacheKey(String fen, AnalysisPreset preset) => '${preset.name}::$fen';

double _whiteWinPercent({
  required num? cp,
  required int? mate,
  required String sideToMove,
}) {
  double sideWinPercent;
  if (mate != null) {
    sideWinPercent = mate > 0 ? 100 : 0;
  } else {
    final boundedCp = cp == null ? 0.0 : cp.clamp(-1000, 1000).toDouble();
    const multiplier = -0.00368208;
    final winChances = 2 / (1 + math.exp(multiplier * boundedCp)) - 1;
    sideWinPercent = 50 + 50 * winChances;
  }

  return sideToMove == 'white' ? sideWinPercent : 100 - sideWinPercent;
}

String _normalizeSan(String san) {
  return san.replaceAll(RegExp(r'[+#?!=]+$'), '');
}

String? _promotionSuffix(String san) {
  final match = RegExp(r'=([QRBN])').firstMatch(san);
  return match?.group(1)?.toLowerCase();
}

_RawEngineLine? _parseInfoLine(String line) {
  final scoreMatch = RegExp(r'score (cp|mate) (-?\d+)').firstMatch(line);
  final pvMatch = RegExp(r' pv (.+)$').firstMatch(line);
  if (scoreMatch == null || pvMatch == null) {
    return null;
  }

  final multiPvMatch = RegExp(r'multipv (\d+)').firstMatch(line);
  final multiPv = int.tryParse(multiPvMatch?.group(1) ?? '1') ?? 1;
  final scoreType = scoreMatch.group(1)!;
  final scoreValue = int.parse(scoreMatch.group(2)!);
  final pvMoves = pvMatch.group(1)!.trim().split(' ');

  return _RawEngineLine(
    multiPv: multiPv,
    cp: scoreType == 'cp' ? scoreValue : null,
    mate: scoreType == 'mate' ? scoreValue : null,
    pvMoves: pvMoves,
  );
}

class _ReconstructedMove {
  const _ReconstructedMove({
    required this.ply,
    required this.san,
    required this.color,
    required this.from,
    required this.to,
    required this.uci,
    required this.fenBefore,
    required this.fenAfter,
  });

  final int ply;
  final String san;
  final String color;
  final String from;
  final String to;
  final String uci;
  final String fenBefore;
  final String fenAfter;
}

class _EngineEval {
  const _EngineEval({
    required this.bestMove,
    required this.whiteWinPercent,
    required this.alternateWhiteWinPercent,
  });

  final String? bestMove;
  final double whiteWinPercent;
  final double? alternateWhiteWinPercent;
}

class _RawEngineLine {
  const _RawEngineLine({
    required this.multiPv,
    required this.cp,
    required this.mate,
    required this.pvMoves,
  });

  final int multiPv;
  final int? cp;
  final int? mate;
  final List<String> pvMoves;
}

class _EngineConfig {
  const _EngineConfig({
    required this.depth,
    required this.multiPv,
    required this.threads,
    required this.hashMb,
  });

  final int depth;
  final int multiPv;
  final int threads;
  final int hashMb;
}
