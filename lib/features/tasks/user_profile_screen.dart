import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ascend_arena/core/providers.dart';

final userProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser!;
  
  final userData = await supabase.from('users').select().eq('id', user.id).single();
  final xpHistory = await supabase.from('xp_transactions').select().eq('user_id', user.id).order('created_at');
  
  return {
    'user': userData,
    'history': xpHistory,
  };
});

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _updateAvatar() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;
      
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Avatar',
            toolbarColor: Colors.amber,
            toolbarWidgetColor: Colors.black,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Crop Avatar', aspectRatioLockEnabled: true),
        ],
      );
      
      if (croppedFile == null) return;
      
      setState(() => _isUploading = true);
      
      final supabase = ref.read(supabaseProvider);
      final userId = supabase.auth.currentUser!.id;
      final fileExt = croppedFile.path.split('.').last;
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      await supabase.storage.from('avatars').upload(fileName, File(croppedFile.path));
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      
      await supabase.from('users').update({'avatar_url': publicUrl}).eq('id', userId);
      ref.invalidate(userProfileProvider);
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar updated!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile & Analytics')),
      body: profileAsync.when(
        data: (data) {
          final user = data['user'];
          final history = data['history'] as List;
          
          List<FlSpot> spots = [];
          if (history.isNotEmpty) {
            double cumulativeXp = 0;
            spots.add(const FlSpot(0, 0)); // Start
            for (int i = 0; i < history.length; i++) {
              cumulativeXp += (history[i]['amount'] as int);
              spots.add(FlSpot((i + 1).toDouble(), cumulativeXp));
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade800,
                      backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                      child: user['avatar_url'] == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                    ),
                    if (_isUploading)
                      const CircularProgressIndicator()
                    else
                      IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.amber),
                        onPressed: _updateAvatar,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(user['display_name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('${user['current_rank'] ?? 'Bronze 5'} - Level ${user['level']}', style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${user['xp']} Total XP', style: const TextStyle(color: Colors.grey)),
                
                const SizedBox(height: 32),
                const Text('XP Progression Over Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                if (spots.length < 2)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('Not enough data for chart yet. Complete more tasks!'),
                  )
                else
                  SizedBox(
                    height: 250,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: const FlTitlesData(
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade800)),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: Colors.amber,
                            barWidth: 3,
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.amber.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                const SizedBox(height: 32),
                const Text('Recent XP Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                ...history.reversed.take(10).map((h) => ListTile(
                  leading: Icon(h['amount'] > 0 ? Icons.trending_up : Icons.trending_down, color: h['amount'] > 0 ? Colors.green : Colors.red),
                  title: Text(h['reason']),
                  subtitle: Text(DateTime.parse(h['created_at']).toLocal().toString().split('.')[0]),
                  trailing: Text('${h['amount'] > 0 ? '+' : ''}${h['amount']} XP', style: TextStyle(fontWeight: FontWeight.bold, color: h['amount'] > 0 ? Colors.green : Colors.red)),
                )),
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
