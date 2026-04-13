enum GameSource {
  lichess('Lichess', 'L'),
  chessCom('Chess.com', 'C');

  const GameSource(this.label, this.shortLabel);

  final String label;
  final String shortLabel;
}

class PlayerSummary {
  const PlayerSummary({required this.name, this.rating, this.title});

  final String name;
  final int? rating;
  final String? title;

  String get displayName {
    if (title == null || title!.isEmpty) {
      return name;
    }
    return '$title $name';
  }
}

class RecentGameSummary {
  const RecentGameSummary({
    required this.id,
    required this.source,
    required this.pgn,
    required this.white,
    required this.black,
    required this.result,
    required this.playedAt,
    required this.url,
    this.timeControl,
    this.movesCount,
    this.opening,
    this.event,
    this.site,
  });

  final String id;
  final GameSource source;
  final String pgn;
  final PlayerSummary white;
  final PlayerSummary black;
  final String result;
  final DateTime playedAt;
  final String url;
  final String? timeControl;
  final int? movesCount;
  final String? opening;
  final String? event;
  final String? site;

  bool involvesUser(String username) {
    final normalized = username.trim().toLowerCase();
    return white.name.toLowerCase() == normalized ||
        black.name.toLowerCase() == normalized;
  }

  bool userPlayedWhite(String username) {
    return white.name.toLowerCase() == username.trim().toLowerCase();
  }

  String opponentOf(String username) {
    if (userPlayedWhite(username)) {
      return black.displayName;
    }
    return white.displayName;
  }

  String get resultLabel {
    switch (result) {
      case '1-0':
        return 'White won';
      case '0-1':
        return 'Black won';
      case '1/2-1/2':
        return 'Draw';
      default:
        return 'In progress';
    }
  }
}

class UserPreferences {
  const UserPreferences({
    this.username,
    this.preferredSource = GameSource.lichess,
    this.autoRefreshHome = true,
  });

  final String? username;
  final GameSource preferredSource;
  final bool autoRefreshHome;

  UserPreferences copyWith({
    String? username,
    bool clearUsername = false,
    GameSource? preferredSource,
    bool? autoRefreshHome,
  }) {
    return UserPreferences(
      username: clearUsername ? null : (username ?? this.username),
      preferredSource: preferredSource ?? this.preferredSource,
      autoRefreshHome: autoRefreshHome ?? this.autoRefreshHome,
    );
  }
}
