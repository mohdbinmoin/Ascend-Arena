import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ascend_arena/core/providers.dart';

class SpeechSubmissionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> task;
  const SpeechSubmissionScreen({super.key, required this.task});

  @override
  ConsumerState<SpeechSubmissionScreen> createState() => _SpeechSubmissionScreenState();
}

class _SpeechSubmissionScreenState extends ConsumerState<SpeechSubmissionScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/speech_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        setState(() {
          _isRecording = true;
          _audioPath = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recording error: $e')));
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stop recording error: $e')));
      }
    }
  }

  Future<void> _submitTask() async {
    if (_audioPath == null) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      final supabase = ref.read(supabaseProvider);
      final file = File(_audioPath!);
      final fileName = 'user_${supabase.auth.currentUser!.id}_task_${widget.task['id']}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      // Upload to Storage
      // Assuming a bucket named 'submissions' exists. Make sure to create it in the Supabase Dashboard!
      await supabase.storage.from('submissions').upload(fileName, file);
      
      final publicUrl = supabase.storage.from('submissions').getPublicUrl(fileName);
      
      // Call the RPC for server-authoritative submission
      final response = await supabase.rpc('submit_task', params: {
        'p_task_id': widget.task['id'],
        'p_file_url': publicUrl,
        'p_text_content': null,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task Submitted! Status ID: $response')));
        Navigator.pop(context);
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit error: $e')));
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Instructions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.task['instructions'] ?? 'No instructions provided.', style: const TextStyle(fontSize: 16)),
            
            const Spacer(),
            
            if (_isRecording)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Recording in progress...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ),
              
            if (_audioPath != null && !_isRecording)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Audio recorded successfully! Ready to submit.', style: TextStyle(color: Colors.green)),
                ),
              ),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isRecording && _audioPath == null)
                  FloatingActionButton.large(
                    onPressed: _startRecording,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.mic, color: Colors.white),
                  ),
                if (_isRecording)
                  FloatingActionButton.large(
                    onPressed: _stopRecording,
                    backgroundColor: Colors.grey,
                    child: const Icon(Icons.stop, color: Colors.white),
                  ),
              ],
            ),
            
            const SizedBox(height: 48),
            
            ElevatedButton(
              onPressed: (_audioPath != null && !_isSubmitting) ? _submitTask : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.black) 
                  : const Text('SUBMIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
