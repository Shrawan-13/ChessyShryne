import 'package:chessy_shryne/src/models.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.preferences,
    required this.onSave,
  });

  final UserPreferences preferences;
  final Future<void> Function(UserPreferences preferences) onSave;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _usernameController;
  late GameSource _selectedSource;
  late AnalysisPreset _analysisPreset;
  late bool _autoRefresh;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.preferences.username ?? '',
    );
    _selectedSource = widget.preferences.preferredSource;
    _analysisPreset = widget.preferences.analysisPreset;
    _autoRefresh = widget.preferences.autoRefreshHome;
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences != widget.preferences) {
      _usernameController.text = widget.preferences.username ?? '';
      _selectedSource = widget.preferences.preferredSource;
      _analysisPreset = widget.preferences.analysisPreset;
      _autoRefresh = widget.preferences.autoRefreshHome;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
    });

    final trimmed = _usernameController.text.trim();
    final preferences = widget.preferences.copyWith(
      username: trimmed,
      clearUsername: trimmed.isEmpty,
      preferredSource: _selectedSource,
      autoRefreshHome: _autoRefresh,
      analysisPreset: _analysisPreset,
    );

    await widget.onSave(preferences);
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(title: Text('Settings')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Your username',
                          hintText: 'e.g. Hikaru or DrNykterstein',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Default source',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<GameSource>(
                        segments: GameSource.values
                            .map(
                              (source) => ButtonSegment<GameSource>(
                                value: source,
                                label: Text(source.label),
                              ),
                            )
                            .toList(),
                        selected: {_selectedSource},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _selectedSource = selection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Analysis quality',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<AnalysisPreset>(
                        segments: AnalysisPreset.values
                            .map(
                              (preset) => ButtonSegment<AnalysisPreset>(
                                value: preset,
                                label: Text(preset.label),
                              ),
                            )
                            .toList(),
                        selected: {_analysisPreset},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _analysisPreset = selection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _autoRefresh,
                        onChanged: (value) {
                          setState(() {
                            _autoRefresh = value;
                          });
                        },
                        title: const Text('Refresh home automatically'),
                        subtitle: const Text(
                          'Load your recent games when the app opens and when your saved identity changes.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _handleSave,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save preferences'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
