import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ascend_arena/core/providers.dart';
import 'package:ascend_arena/features/admin/task_creation_screen.dart';
import 'package:ascend_arena/features/admin/scoring_screen.dart';
import 'package:ascend_arena/features/auth/profile_selection_screen.dart';
import 'package:ascend_arena/features/admin/admin_users_screen.dart';

final pendingSubmissionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  
  // Fetch submissions that do not have a corresponding score yet
  // We use a left join on scores and filter where scores.id is null
  final response = await supabase
      .from('submissions')
      .select('*, tasks!inner(*, scoring_presets(*)), users(*), scores(id)')
      .isFilter('scores.id', null)
      .order('submitted_at', ascending: true);

  // Filter out those that actually got joined with a score
  final pending = (response as List<dynamic>)
      .where((s) => s['scores'] == null || (s['scores'] is List && (s['scores'] as List).isEmpty) || (s['scores'] is Map && (s['scores'] as Map).isEmpty))
      .map((e) => e as Map<String, dynamic>)
      .toList();
      
  return pending;
});

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingSubmissionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Arena'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.switch_account),
            onPressed: () async {
              await ref.read(supabaseProvider).auth.signOut(scope: SignOutScope.local);
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
                  (route) => false,
                );
              }
            },
          )
        ],
      ),
      body: pendingAsync.when(
        data: (submissions) {
          if (submissions.isEmpty) {
            return const Center(child: Text('No pending submissions to score!'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              final sub = submissions[index];
              final task = sub['tasks'];
              final user = sub['users'];
              
              return Card(
                child: ListTile(
                  title: Text('${user['display_name']} - ${task['title']}'),
                  subtitle: Text('Status: ${sub['status']} | Submitted: ${DateTime.parse(sub['submitted_at']).toLocal().toString().split('.')[0]}'),
                  trailing: const Icon(Icons.grade, color: Colors.amber),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ScoringScreen(submission: sub)),
                    ).then((_) => ref.refresh(pendingSubmissionsProvider));
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskCreationScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
    );
  }
}
