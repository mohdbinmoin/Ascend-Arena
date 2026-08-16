import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ascend_arena/core/providers.dart';
import 'package:ascend_arena/features/tasks/speech_submission_screen.dart';
import 'package:ascend_arena/features/tasks/writing_submission_screen.dart';
import 'package:ascend_arena/features/tasks/reading_submission_screen.dart';
import 'package:ascend_arena/features/leaderboard/leaderboard_screen.dart';
import 'package:ascend_arena/features/auth/profile_selection_screen.dart';
import 'package:ascend_arena/features/trophies/trophy_cabinet_screen.dart';

final activeTasksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final response = await supabase
      .from('tasks')
      .select()
      .eq('assigned_user_id', user.id)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});

class UserDashboard extends ConsumerWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(activeTasksProvider);
    final user = ref.read(supabaseProvider).auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Arena'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            color: Colors.amber,
            onPressed: () {
              if (user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TrophyCabinetScreen(userId: user.id, displayName: 'My')),
                );
              }
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
      body: tasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('No active tasks! You are all caught up.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final type = task['type'];
              
              IconData icon;
              if (type == 'speech') icon = Icons.mic;
              else if (type == 'writing') icon = Icons.edit;
              else icon = Icons.menu_book;
              
              return Card(
                child: ListTile(
                  leading: Icon(icon, color: Colors.amber),
                  title: Text(task['title']),
                  subtitle: Text('Type: $type'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Widget screen;
                    if (type == 'speech') {
                      screen = SpeechSubmissionScreen(task: task);
                    } else if (type == 'writing') {
                      screen = WritingSubmissionScreen(task: task);
                    } else {
                      screen = ReadingSubmissionScreen(task: task);
                    }
                    
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => screen),
                    );
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
          Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
        },
        icon: const Icon(Icons.leaderboard),
        label: const Text('Leaderboard'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
      ),
    );
  }
}
