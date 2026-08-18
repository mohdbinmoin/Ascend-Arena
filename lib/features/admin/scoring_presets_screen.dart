import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascend_arena/core/providers.dart';

final presetsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.from('scoring_presets').select().order('name');
  return List<Map<String, dynamic>>.from(response);
});

class ScoringPresetsScreen extends ConsumerWidget {
  const ScoringPresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(presetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Presets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PresetEditorScreen()));
            },
          )
        ],
      ),
      body: presetsAsync.when(
        data: (presets) {
          if (presets.isEmpty) return const Center(child: Text('No presets found.'));
          return ListView.builder(
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final preset = presets[index];
              final criteria = preset['criteria'] as Map<String, dynamic>;
              
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(preset['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Max Scale: ${preset['scale']}\nCriteria: ${criteria.keys.join(', ')}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Delete Preset?'),
                          content: const Text('Are you sure you want to delete this preset? Tasks using it might break if not handled properly.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCEL')),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
                          ],
                        )
                      );
                      
                      if (confirm == true) {
                        try {
                          await ref.read(supabaseProvider).from('scoring_presets').delete().eq('id', preset['id']);
                          ref.invalidate(presetsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preset deleted')));
                          }
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                  ),
                  onTap: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => PresetEditorScreen(existingPreset: preset)));
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class PresetEditorScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existingPreset;
  const PresetEditorScreen({super.key, this.existingPreset});

  @override
  ConsumerState<PresetEditorScreen> createState() => _PresetEditorScreenState();
}

class _PresetEditorScreenState extends ConsumerState<PresetEditorScreen> {
  final _nameController = TextEditingController();
  final List<Map<String, TextEditingController>> _criteriaControllers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingPreset != null) {
      _nameController.text = widget.existingPreset!['name'];
      final criteria = widget.existingPreset!['criteria'] as Map<String, dynamic>;
      for (final entry in criteria.entries) {
        _criteriaControllers.add({
          'name': TextEditingController(text: entry.key),
          'points': TextEditingController(text: entry.value.toString()),
        });
      }
    } else {
      _addCriterion();
    }
  }

  void _addCriterion() {
    setState(() {
      _criteriaControllers.add({
        'name': TextEditingController(),
        'points': TextEditingController(),
      });
    });
  }

  void _removeCriterion(int index) {
    setState(() {
      _criteriaControllers.removeAt(index);
    });
  }

  Future<void> _savePreset() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }

    final Map<String, int> criteria = {};
    int totalScale = 0;

    for (final controllers in _criteriaControllers) {
      final name = controllers['name']!.text.trim();
      final points = int.tryParse(controllers['points']!.text.trim());
      
      if (name.isEmpty || points == null || points <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All criteria must have a valid name and points > 0')));
        return;
      }
      criteria[name] = points;
      totalScale += points;
    }

    if (criteria.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one criterion')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'name': _nameController.text.trim(),
        'criteria': criteria,
        'scale': totalScale,
      };

      if (widget.existingPreset != null) {
        await ref.read(supabaseProvider).from('scoring_presets').update(data).eq('id', widget.existingPreset!['id']);
      } else {
        await ref.read(supabaseProvider).from('scoring_presets').insert(data);
      }
      
      ref.invalidate(presetsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preset saved!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existingPreset == null ? 'New Preset' : 'Edit Preset')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Preset Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            const Text('Criteria & Max Points', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            
            ...List.generate(_criteriaControllers.length, (index) {
              final controllers = _criteriaControllers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: controllers['name'],
                        decoration: const InputDecoration(labelText: 'Name (e.g. Grammar)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: controllers['points'],
                        decoration: const InputDecoration(labelText: 'Max Points'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _removeCriterion(index),
                    )
                  ],
                ),
              );
            }),
            
            TextButton.icon(
              onPressed: _addCriterion, 
              icon: const Icon(Icons.add), 
              label: const Text('Add Criterion')
            ),
            
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _savePreset,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: _isLoading ? const CircularProgressIndicator() : const Text('SAVE PRESET', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
