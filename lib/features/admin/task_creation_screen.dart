import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascend_arena/core/providers.dart';

class TaskCreationScreen extends ConsumerStatefulWidget {
  const TaskCreationScreen({super.key});

  @override
  ConsumerState<TaskCreationScreen> createState() => _TaskCreationScreenState();
}

class _TaskCreationScreenState extends ConsumerState<TaskCreationScreen> {
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _graceController = TextEditingController(text: '300'); // Default 5 mins
  
  String? _selectedUserId;
  String? _selectedPresetId;
  String _taskType = 'speech';
  
  DateTime? _windowStart;
  DateTime? _windowEnd;
  
  bool _isLoading = false;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _presets = [];

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    final supabase = ref.read(supabaseProvider);
    
    // In a real app, you'd use Riverpod providers for this, but for the form we'll fetch directly
    final usersData = await supabase.from('users').select().eq('role', 'user');
    final presetsData = await supabase.from('scoring_presets').select();

    setState(() {
      _users = List<Map<String, dynamic>>.from(usersData);
      _presets = List<Map<String, dynamic>>.from(presetsData);
      
      if (_users.isNotEmpty) _selectedUserId = _users.first['id'];
      if (_presets.isNotEmpty) _selectedPresetId = _presets.first['id'];
    });
  }

  Future<void> _pickDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    
    final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _windowStart = dateTime;
      } else {
        _windowEnd = dateTime;
      }
    });
  }

  Future<void> _createTask() async {
    if (_titleController.text.isEmpty || _selectedUserId == null || _selectedPresetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('tasks').insert({
        'type': _taskType,
        'title': _titleController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'assigned_user_id': _selectedUserId,
        'window_start': _windowStart?.toIso8601String(),
        'window_end': _windowEnd?.toIso8601String(),
        'grace_seconds': int.tryParse(_graceController.text) ?? 30,
        'preset_id': _selectedPresetId,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task created!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Task')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _taskType,
              decoration: const InputDecoration(labelText: 'Task Type'),
              items: const [
                DropdownMenuItem(value: 'speech', child: Text('Speech Task')),
                DropdownMenuItem(value: 'writing', child: Text('Writing Task')),
                DropdownMenuItem(value: 'reading', child: Text('Reading Task')),
              ],
              onChanged: (val) => setState(() => _taskType = val!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Task Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _instructionsController,
              decoration: const InputDecoration(labelText: 'Instructions', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            // Assign User
            DropdownButtonFormField<String>(
              value: _selectedUserId,
              decoration: const InputDecoration(labelText: 'Assign To'),
              items: _users.map((u) => DropdownMenuItem<String>(value: u['id'], child: Text(u['display_name']))).toList(),
              onChanged: (val) => setState(() => _selectedUserId = val),
            ),
            const SizedBox(height: 16),
            
            // Preset
            DropdownButtonFormField<String>(
              value: _selectedPresetId,
              decoration: const InputDecoration(labelText: 'Scoring Preset'),
              items: _presets.map((p) => DropdownMenuItem<String>(value: p['id'], child: Text(p['name']))).toList(),
              onChanged: (val) => setState(() => _selectedPresetId = val),
            ),
            if (_presets.isEmpty) 
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Warning: No scoring presets exist. Please create one in the database first.', style: TextStyle(color: Colors.red)),
              ),
              
            const SizedBox(height: 24),
            const Text('Time Constraints (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(_windowStart != null ? 'Start: ${_windowStart!.hour}:${_windowStart!.minute}' : 'Set Start Time'),
                    onPressed: () => _pickDateTime(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(_windowEnd != null ? 'End: ${_windowEnd!.hour}:${_windowEnd!.minute}' : 'Set End Time'),
                    onPressed: () => _pickDateTime(false),
                  ),
                ),
              ],
            ),
            if (_windowStart != null || _windowEnd != null)
              TextButton(onPressed: () => setState(() { _windowStart = null; _windowEnd = null; }), child: const Text('Clear Times')),
              
            const SizedBox(height: 16),
            TextField(
              controller: _graceController,
              decoration: const InputDecoration(labelText: 'Grace Period (Seconds)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _createTask,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.black) 
                  : const Text('CREATE TASK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
