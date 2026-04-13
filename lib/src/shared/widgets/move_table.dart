import 'package:flutter/material.dart';

class MoveTable extends StatelessWidget {
  const MoveTable({super.key, required this.moves});

  final List<String> moves;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Table(
      columnWidths: const {
        0: FixedColumnWidth(36),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('#', style: textTheme.labelLarge),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('White', style: textTheme.labelLarge),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Black', style: textTheme.labelLarge),
            ),
          ],
        ),
        for (var index = 0; index < moves.length; index += 2)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('${(index ~/ 2) + 1}'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(moves[index]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(index + 1 < moves.length ? moves[index + 1] : ''),
              ),
            ],
          ),
      ],
    );
  }
}
