import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascend_arena/core/providers.dart';

final usersListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('users')
      .select('*, visibility_settings(*)')
      .eq('role', 'user')
      .order('display_name');
  return List<Map<String, dynamic>>.from(response);
});

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  Future<void> _toggleVisibility(String userId, bool currentVal) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('visibility_settings')
          .update({'hide_alltime': !currentVal})
          .eq('user_id', userId);
      
      ref.invalidate(usersListProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _awardTrophy(String userId, String type) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('trophies').insert({
        'user_id': userId,
        'type': type,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type trophy awarded!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showAwardDialog(String userId, String displayName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Award Trophy to $displayName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.emoji_events, color: Colors.amber),
                title: const Text('Gold Trophy'),
                onTap: () {
                  Navigator.pop(context);
                  _awardTrophy(userId, 'gold');
                },
              ),
              ListTile(
                leading: Icon(Icons.emoji_events, color: Colors.grey.shade400),
                title: const Text('Silver Trophy'),
                onTap: () {
                  Navigator.pop(context);
                  _awardTrophy(userId, 'silver');
                },
              ),
              ListTile(
                leading: Icon(Icons.emoji_events, color: Colors.brown.shade400),
                title: const Text('Bronze Trophy'),
                onTap: () {
                  Navigator.pop(context);
                  _awardTrophy(userId, 'bronze');
                },
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) return const Center(child: Text('No users found.'));
          
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final settings = (user['visibility_settings'] as List).isNotEmpty 
                  ? user['visibility_settings'][0] 
                  : {'hide_alltime': false};
              
              final isHidden = settings['hide_alltime'] == true;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(user['display_name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.emoji_events, color: Colors.amber),
                            tooltip: 'Award Trophy',
                            onPressed: () => _showAwardDialog(user['id'], user['display_name']),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Hide from Leaderboard?'),
                          Switch(
                            value: isHidden,
                            onChanged: (val) => _toggleVisibility(user['id'], isHidden),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
