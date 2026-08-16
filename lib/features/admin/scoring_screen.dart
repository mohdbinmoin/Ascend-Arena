import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:ascend_arena/core/providers.dart';

class ScoringScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> submission;
  
  const ScoringScreen({super.key, required this.submission});

  @override
  ConsumerState<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends ConsumerState<ScoringScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  
  final Map<String, TextEditingController> _scoreControllers = {};
  bool _isSubmitting = false;
  
  late Map<String, dynamic> _criteria;
  late num _scale;

  @override
  void initState() {
    super.initState();
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    final preset = widget.submission['tasks']['scoring_presets'];
    _criteria = Map<String, dynamic>.from(preset['criteria']);
    _scale = preset['scale'];
    
    for (final key in _criteria.keys) {
      _scoreControllers[key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    for (var c in _scoreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    final url = widget.submission['file_url'];
    if (url == null) return;
    
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(url));
    }
  }

  Future<void> _submitScores() async {
    // Validate
    final Map<String, num> inputtedScores = {};
    num totalScore = 0;
    
    for (final entry in _criteria.entries) {
      final key = entry.key;
      final maxScore = entry.value;
      
      final text = _scoreControllers[key]?.text.trim() ?? '';
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please score "$key"')));
        return;
      }
      
      final val = num.tryParse(text);
      if (val == null || val < 0 || val > maxScore) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid score for "$key" (0-$maxScore)')));
        return;
      }
      
      inputtedScores[key] = val;
      totalScore += val;
    }

    setState(() => _isSubmitting = true);
    
    try {
      final supabase = ref.read(supabaseProvider);
      
      await supabase.from('scores').insert({
        'submission_id': widget.submission['id'],
        'criteria_scores': inputtedScores,
        'total_score': totalScore,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scores submitted successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving scores: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.submission['tasks'];
    final user = widget.submission['users'];
    final preset = task['scoring_presets'];

    return Scaffold(
      appBar: AppBar(title: Text('Score ${user['display_name']}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Task: ${task['title']}', style: Theme.of(context).textTheme.titleLarge),
            Text('Timing Status: ${widget.submission['status']}'),
            const SizedBox(height: 24),
            
            if (widget.submission['file_url'] != null)
              if (task['type'] == 'speech')
                Card(
                  color: Colors.grey.shade900,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle, size: 48, color: Colors.amber),
                          onPressed: _toggleAudio,
                        ),
                        const SizedBox(width: 16),
                        const Expanded(child: Text('Listen to Submission')),
                      ],
                    ),
                  ),
                )
              else if (task['type'] == 'writing')
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.submission['file_url'],
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                )
            else if (task['type'] == 'reading')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Text(
                  widget.submission['content'] ?? 'No summary provided.',
                  style: const TextStyle(fontSize: 16),
                ),
              )
            else
              const Text('No content attached.', style: TextStyle(color: Colors.red)),
              
            const SizedBox(height: 32),
            Text('Scoring Preset: ${preset['name']} (Max $_scale)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            
            ..._criteria.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(child: Text('${entry.key} (Max ${entry.value})', style: const TextStyle(fontSize: 16))),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _scoreControllers[entry.key],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '0',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }),
            
            const SizedBox(height: 48),
            
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitScores,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('SUBMIT FINAL SCORE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
