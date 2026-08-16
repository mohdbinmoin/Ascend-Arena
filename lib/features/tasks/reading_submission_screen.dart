import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ascend_arena/core/providers.dart';
import 'package:ascend_arena/features/tasks/user_dashboard.dart';

class ReadingSubmissionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> task;

  const ReadingSubmissionScreen({super.key, required this.task});

  @override
  ConsumerState<ReadingSubmissionScreen> createState() => _ReadingSubmissionScreenState();
}

class _ReadingSubmissionScreenState extends ConsumerState<ReadingSubmissionScreen> {
  final _summaryController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitReading() async {
    final content = _summaryController.text.trim();
    if (content.isEmpty) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      final supabase = ref.read(supabaseProvider);
      final user = supabase.auth.currentUser!;
      
      // Call RPC with text content instead of a file URL
      final response = await supabase.rpc('submit_task', params: {
        'p_task_id': widget.task['id'],
        'p_user_id': user.id,
        'p_file_url': null,
        'p_content': content
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Success! Status: $response')));
        ref.invalidate(activeTasksProvider);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.task['title'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Instructions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.task['instructions'] ?? 'No special instructions.'),
            const SizedBox(height: 32),
            
            TextField(
              controller: _summaryController,
              decoration: const InputDecoration(
                labelText: 'Reading Summary',
                hintText: 'What did you read about? What were the key takeaways?',
                border: OutlineInputBorder(),
              ),
              maxLines: 8,
              keyboardType: TextInputType.multiline,
            ),
              
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReading,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.black) 
                  : const Text('SUBMIT READING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
