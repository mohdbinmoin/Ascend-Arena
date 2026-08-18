import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ascend_arena/core/providers.dart';
import 'package:ascend_arena/features/tasks/user_dashboard.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ascend_arena/core/offline_storage.dart';
import 'package:ascend_arena/core/background_sync.dart';

class WritingSubmissionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> task;

  const WritingSubmissionScreen({super.key, required this.task});

  @override
  ConsumerState<WritingSubmissionScreen> createState() => _WritingSubmissionScreenState();
}

class _WritingSubmissionScreenState extends ConsumerState<WritingSubmissionScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isSubmitting = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _submitWriting() async {
    if (_selectedImage == null) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      final supabase = ref.read(supabaseProvider);
      final user = supabase.auth.currentUser!;
      
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.none)) {
        // Offline - Queue for background upload
        await OfflineStorage.addPendingUpload(user.id, widget.task['id'], _selectedImage!.path);
        BackgroundSync.registerSyncTask();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline: Task queued for background upload!')));
          Navigator.pop(context);
        }
        return;
      }
      
      // Upload to Storage
      final fileExt = _selectedImage!.path.split('.').last;
      final fileName = '${user.id}_${widget.task['id']}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'writing/$fileName';
      
      await supabase.storage
          .from('submissions')
          .upload(filePath, _selectedImage!);
          
      final publicUrl = supabase.storage.from('submissions').getPublicUrl(filePath);
      
      // Call RPC
      final response = await supabase.rpc('submit_task', params: {
        'p_task_id': widget.task['id'],
        'p_user_id': user.id,
        'p_file_url': publicUrl,
        'p_content': null
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
            
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: const Center(child: Text('No image selected', style: TextStyle(color: Colors.grey))),
              ),
              
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ],
            ),
            
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: (_selectedImage == null || _isSubmitting) ? null : _submitWriting,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.black) 
                  : const Text('SUBMIT WRITING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
