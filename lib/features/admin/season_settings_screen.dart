import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascend_arena/core/providers.dart';

final appSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.from('app_settings').select().eq('id', 'default').single();
  return response;
});

class SeasonSettingsScreen extends ConsumerStatefulWidget {
  const SeasonSettingsScreen({super.key});

  @override
  ConsumerState<SeasonSettingsScreen> createState() => _SeasonSettingsScreenState();
}

class _SeasonSettingsScreenState extends ConsumerState<SeasonSettingsScreen> {
  final _nameController = TextEditingController();
  DateTime? _seasonEnd;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Season Configuration')),
      body: settingsAsync.when(
        data: (settings) {
          if (_nameController.text.isEmpty) {
            _nameController.text = settings['season_name'] ?? 'Season 1';
            _seasonEnd = settings['season_end'] != null ? DateTime.parse(settings['season_end']) : null;
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Season Name (e.g. Season 1)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                
                ListTile(
                  title: const Text('Season End Date'),
                  subtitle: Text(_seasonEnd != null ? _seasonEnd!.toLocal().toString().split('.')[0] : 'Not Set'),
                  trailing: const Icon(Icons.calendar_today),
                  tileColor: Colors.grey.shade900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _seasonEnd ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          _seasonEnd = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        });
                      }
                    }
                  },
                ),
                
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    setState(() => _isLoading = true);
                    try {
                      await ref.read(supabaseProvider).from('app_settings').update({
                        'season_name': _nameController.text.trim(),
                        'season_end': _seasonEnd?.toIso8601String(),
                      }).eq('id', 'default');
                      
                      ref.invalidate(appSettingsProvider);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Season Settings Saved!')));
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  child: _isLoading ? const CircularProgressIndicator() : const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
