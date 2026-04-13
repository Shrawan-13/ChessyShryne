import 'package:chessy_shryne/src/features/analysis/analysis_models.dart';
import 'package:chessy_shryne/src/features/analysis/game_analysis_service.dart';
import 'package:chessy_shryne/src/models.dart';
import 'package:chessy_shryne/src/pgn.dart';
import 'package:flutter/material.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    super.key,
    required this.game,
    required this.analysisService,
    required this.preset,
  });

  final RecentGameSummary game;
  final GameAnalysisService analysisService;
  final AnalysisPreset preset;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late final Future<GameAnalysisData> _analysisFuture;
  int _selectedPly = 0;

  @override
  void initState() {
    super.initState();
    _analysisFuture = widget.analysisService.analyzeGame(
      widget.game,
      widget.preset,
    );
  }

  void _goToPly(int ply) {
    setState(() {
      _selectedPly = ply;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    return Scaffold(
      body: FutureBuilder<GameAnalysisData>(
        future: _analysisFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _AnalysisLoadingView();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _AnalysisErrorView(
              onRetry: () {
                setState(() {});
              },
            );
          }

          final analysis = snapshot.data!;
          final maxPly = analysis.moves.length;
          final safeSelectedPly = _selectedPly.clamp(0, maxPly);
          final currentMove = safeSelectedPly == 0
              ? null
              : analysis.moves[safeSelectedPly - 1];
          final currentFen = currentMove?.fenAfter ?? analysis.initialFen;

          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: const Text('Game Analysis'),
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
                    _AnalysisHeader(game: game, preset: widget.preset),
                    const SizedBox(height: 20),
                    _BoardCard(
                      fen: currentFen,
                      move: currentMove,
                      selectedPly: safeSelectedPly,
                      totalPlies: maxPly,
                      onPrevious: safeSelectedPly > 0
                          ? () => _goToPly(safeSelectedPly - 1)
                          : null,
                      onNext: safeSelectedPly < maxPly
                          ? () => _goToPly(safeSelectedPly + 1)
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _SummaryCard(
                      white: game.white.displayName,
                      black: game.black.displayName,
                      whiteSummary: analysis.whiteSummary,
                      blackSummary: analysis.blackSummary,
                    ),
                    const SizedBox(height: 20),
                    _MovesCard(
                      moves: analysis.moves,
                      selectedPly: safeSelectedPly,
                      onSelectPly: _goToPly,
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnalysisHeader extends StatelessWidget {
  const _AnalysisHeader({required this.game, required this.preset});

  final RecentGameSummary game;
  final AnalysisPreset preset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              game.opening ?? 'Game analysis',
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
                Chip(label: Text('${preset.label} analysis')),
                if (game.timeControl != null)
                  Chip(label: Text(game.timeControl!)),
                Chip(label: Text(formatLongDate(game.playedAt))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.fen,
    required this.move,
    required this.selectedPly,
    required this.totalPlies,
    required this.onPrevious,
    required this.onNext,
  });

  final String fen;
  final AnalyzedMove? move;
  final int selectedPly;
  final int totalPlies;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final quality = move?.quality;
    final currentMove = move;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: _ChessBoardView(fen: fen, move: move),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPrevious,
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onNext,
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: const Text('Next'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              currentMove == null
                  ? 'Start position'
                  : 'Move $selectedPly/$totalPlies • ${currentMove.san}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (quality != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QualityChip(quality: quality),
                  Chip(label: Text('${currentMove!.from} → ${currentMove.to}')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.white,
    required this.black,
    required this.whiteSummary,
    required this.blackSummary,
  });

  final String white;
  final String black;
  final MoveQualitySummary whiteSummary;
  final MoveQualitySummary blackSummary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Move quality', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 88),
                Expanded(
                  child: Text(
                    white,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    black,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final quality in MoveQuality.values) ...[
              _SummaryRow(
                label: quality.label,
                whiteValue: whiteSummary.valueFor(quality),
                blackValue: blackSummary.valueFor(quality),
                quality: quality,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.whiteValue,
    required this.blackValue,
    required this.quality,
  });

  final String label;
  final int whiteValue;
  final int blackValue;
  final MoveQuality quality;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: _SummaryValue(value: whiteValue, quality: quality),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryValue(value: blackValue, quality: quality),
        ),
      ],
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.value, required this.quality});

  final int value;
  final MoveQuality quality;

  @override
  Widget build(BuildContext context) {
    final color = _qualityColor(context, quality);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$value',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
      ),
    );
  }
}

class _MovesCard extends StatelessWidget {
  const _MovesCard({
    required this.moves,
    required this.selectedPly,
    required this.onSelectPly,
  });

  final List<AnalyzedMove> moves;
  final int selectedPly;
  final ValueChanged<int> onSelectPly;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Moves', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (var index = 0; index < moves.length; index += 2) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${(index ~/ 2) + 1}.',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Expanded(
                    child: _MoveButton(
                      move: moves[index],
                      isSelected: selectedPly == index + 1,
                      onTap: () => onSelectPly(index + 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: index + 1 < moves.length
                        ? _MoveButton(
                            move: moves[index + 1],
                            isSelected: selectedPly == index + 2,
                            onTap: () => onSelectPly(index + 2),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({
    required this.move,
    required this.isSelected,
    required this.onTap,
  });

  final AnalyzedMove move;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final qualityColor = _qualityColor(context, move.quality);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? qualityColor.withValues(alpha: 0.18)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? qualityColor
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                move.san,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            _QualityChip(quality: move.quality, compact: true),
          ],
        ),
      ),
    );
  }
}

class _QualityChip extends StatelessWidget {
  const _QualityChip({required this.quality, this.compact = false});

  final MoveQuality quality;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _qualityColor(context, quality);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        compact ? quality.shortLabel : quality.label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}

class _ChessBoardView extends StatelessWidget {
  const _ChessBoardView({required this.fen, required this.move});

  final String fen;
  final AnalyzedMove? move;

  @override
  Widget build(BuildContext context) {
    final pieces = _piecesFromFen(fen);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 64,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
      ),
      itemBuilder: (context, index) {
        final rank = 8 - (index ~/ 8);
        final file = index % 8;
        final square = '${'abcdefgh'[file]}$rank';
        final isLightSquare = (file + rank).isEven;
        final piece = pieces[square];
        final isTarget = move?.to == square;
        final isSource = move?.from == square;
        final quality = move?.quality;
        final background = isTarget
            ? _qualityColor(context, quality!).withValues(alpha: 0.28)
            : isSource
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
            : isLightSquare
            ? const Color(0xFFF0D9B5)
            : const Color(0xFFB58863);

        return Container(
          decoration: BoxDecoration(
            color: background,
            border: Border.all(
              color: isTarget && quality != null
                  ? _qualityColor(context, quality)
                  : Colors.transparent,
              width: isTarget ? 2 : 0,
            ),
          ),
          child: Stack(
            children: [
              if (piece != null)
                Center(
                  child: Text(
                    _pieceSymbol(piece),
                    style: TextStyle(
                      fontSize: 28,
                      color: piece == piece.toUpperCase()
                          ? Colors.white
                          : const Color(0xFF1B1B1F),
                      shadows: const [
                        Shadow(
                          blurRadius: 3,
                          color: Colors.black26,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isTarget && quality != null)
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _qualityColor(context, quality),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      quality.shortLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AnalysisLoadingView extends StatelessWidget {
  const _AnalysisLoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Analysis')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _AnalysisErrorView extends StatelessWidget {
  const _AnalysisErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Analysis')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40),
              const SizedBox(height: 12),
              Text(
                'Could not analyze this game right now.',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, String> _piecesFromFen(String fen) {
  final board = <String, String>{};
  final rows = fen.split(' ').first.split('/');

  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    var fileIndex = 0;
    for (final char in rows[rowIndex].split('')) {
      final empty = int.tryParse(char);
      if (empty != null) {
        fileIndex += empty;
        continue;
      }

      final square = '${'abcdefgh'[fileIndex]}${8 - rowIndex}';
      board[square] = char;
      fileIndex += 1;
    }
  }

  return board;
}

String _pieceSymbol(String piece) {
  const symbols = <String, String>{
    'P': '♙',
    'N': '♘',
    'B': '♗',
    'R': '♖',
    'Q': '♕',
    'K': '♔',
    'p': '♟',
    'n': '♞',
    'b': '♝',
    'r': '♜',
    'q': '♛',
    'k': '♚',
  };

  return symbols[piece] ?? '';
}

Color _qualityColor(BuildContext context, MoveQuality quality) {
  switch (quality) {
    case MoveQuality.brilliant:
      return const Color(0xFF00A6A6);
    case MoveQuality.great:
      return const Color(0xFF2E8B57);
    case MoveQuality.best:
      return const Color(0xFF1E88E5);
    case MoveQuality.excellent:
      return const Color(0xFF43A047);
    case MoveQuality.good:
      return Theme.of(context).colorScheme.primary;
    case MoveQuality.inaccuracy:
      return const Color(0xFFF9A825);
    case MoveQuality.mistake:
      return const Color(0xFFEF6C00);
    case MoveQuality.blunder:
      return const Color(0xFFC62828);
  }
}
