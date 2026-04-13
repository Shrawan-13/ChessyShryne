enum MoveQuality {
  brilliant,
  great,
  best,
  excellent,
  good,
  inaccuracy,
  mistake,
  blunder,
}

extension MoveQualityPresentation on MoveQuality {
  String get label {
    switch (this) {
      case MoveQuality.brilliant:
        return 'Brilliant';
      case MoveQuality.great:
        return 'Great';
      case MoveQuality.best:
        return 'Best';
      case MoveQuality.excellent:
        return 'Excellent';
      case MoveQuality.good:
        return 'Good';
      case MoveQuality.inaccuracy:
        return 'Inaccuracy';
      case MoveQuality.mistake:
        return 'Mistake';
      case MoveQuality.blunder:
        return 'Blunder';
    }
  }

  String get shortLabel {
    switch (this) {
      case MoveQuality.brilliant:
        return 'BR';
      case MoveQuality.great:
        return 'GR';
      case MoveQuality.best:
        return 'BS';
      case MoveQuality.excellent:
        return 'EX';
      case MoveQuality.good:
        return 'GD';
      case MoveQuality.inaccuracy:
        return 'IN';
      case MoveQuality.mistake:
        return 'MI';
      case MoveQuality.blunder:
        return 'BL';
    }
  }
}

class AnalyzedMove {
  const AnalyzedMove({
    required this.ply,
    required this.san,
    required this.color,
    required this.from,
    required this.to,
    required this.uci,
    required this.fenAfter,
    required this.quality,
    this.bestMove,
  });

  final int ply;
  final String san;
  final String color;
  final String from;
  final String to;
  final String uci;
  final String fenAfter;
  final MoveQuality quality;
  final String? bestMove;
}

class MoveQualitySummary {
  const MoveQualitySummary(this.counts);

  final Map<MoveQuality, int> counts;

  int valueFor(MoveQuality quality) => counts[quality] ?? 0;

  factory MoveQualitySummary.fromMoves(
    Iterable<AnalyzedMove> moves,
    String color,
  ) {
    final counts = <MoveQuality, int>{
      for (final quality in MoveQuality.values) quality: 0,
    };

    for (final move in moves.where((move) => move.color == color)) {
      counts[move.quality] = (counts[move.quality] ?? 0) + 1;
    }

    return MoveQualitySummary(counts);
  }
}

class GameAnalysisData {
  const GameAnalysisData({
    required this.initialFen,
    required this.moves,
    required this.whiteSummary,
    required this.blackSummary,
  });

  final String initialFen;
  final List<AnalyzedMove> moves;
  final MoveQualitySummary whiteSummary;
  final MoveQualitySummary blackSummary;
}
