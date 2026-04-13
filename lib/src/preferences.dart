import 'package:chessy_shryne/src/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class PreferencesStore {
  Future<UserPreferences> load();

  Future<void> save(UserPreferences preferences);
}

class SharedPreferencesStore implements PreferencesStore {
  static const _usernameKey = 'username';
  static const _preferredSourceKey = 'preferred_source';
  static const _autoRefreshKey = 'auto_refresh_home';

  @override
  Future<UserPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final sourceName = prefs.getString(_preferredSourceKey);
    final source = GameSource.values.firstWhere(
      (value) => value.name == sourceName,
      orElse: () => GameSource.lichess,
    );

    return UserPreferences(
      username: prefs.getString(_usernameKey),
      preferredSource: source,
      autoRefreshHome: prefs.getBool(_autoRefreshKey) ?? true,
    );
  }

  @override
  Future<void> save(UserPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();

    final username = preferences.username?.trim() ?? '';
    if (username.isEmpty) {
      await prefs.remove(_usernameKey);
    } else {
      await prefs.setString(_usernameKey, username);
    }

    await prefs.setString(
      _preferredSourceKey,
      preferences.preferredSource.name,
    );
    await prefs.setBool(_autoRefreshKey, preferences.autoRefreshHome);
  }
}

class MemoryPreferencesStore implements PreferencesStore {
  MemoryPreferencesStore([this._preferences = const UserPreferences()]);

  UserPreferences _preferences;

  @override
  Future<UserPreferences> load() async => _preferences;

  @override
  Future<void> save(UserPreferences preferences) async {
    _preferences = preferences;
  }
}
