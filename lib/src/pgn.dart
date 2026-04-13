Map<String, String> parsePgnHeaders(String pgn) {
  final headerPattern = RegExp(r'^\[(\w+)\s+"(.*)"\]$', multiLine: true);
  final headers = <String, String>{};

  for (final match in headerPattern.allMatches(pgn)) {
    headers[match.group(1)!] = match.group(2) ?? '';
  }

  return headers;
}

List<String> parseMoveList(String pgn) {
  final parts = pgn.split(RegExp(r'\n\s*\n'));
  if (parts.length < 2) {
    return const [];
  }

  var movesSection = parts.sublist(1).join(' ');
  movesSection = movesSection.replaceAll(RegExp(r'\{[^}]*\}'), ' ');
  movesSection = movesSection.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  movesSection = movesSection.replaceAll(RegExp(r'\$\d+'), ' ');
  movesSection = movesSection.replaceAll(RegExp(r'\d+\.(\.\.)?'), ' ');

  final tokens = movesSection
      .split(RegExp(r'\s+'))
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .where(
        (token) =>
            token != '1-0' &&
            token != '0-1' &&
            token != '1/2-1/2' &&
            token != '*',
      )
      .toList();

  return tokens;
}

String formatLongDate(DateTime date) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String formatShortDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month/$day/${date.year}';
}

String formatRelativeDay(DateTime date) {
  final localNow = DateTime.now();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final target = DateTime(date.year, date.month, date.day);
  final difference = today.difference(target).inDays;

  if (difference <= 0) {
    return 'Today';
  }
  if (difference == 1) {
    return 'Yesterday';
  }
  if (difference < 7) {
    return '$difference days ago';
  }
  return formatShortDate(date);
}
