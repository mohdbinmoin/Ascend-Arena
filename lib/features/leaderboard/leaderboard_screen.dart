import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ascend_arena/core/providers.dart';

final leaderboardProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  
  // Realtime subscription: When any score is inserted/updated, invalidate this provider to re-fetch
  final sub = supabase.channel('public:scores').onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'scores',
    callback: (payload) {
      ref.invalidateSelf();
    },
  ).subscribe();

  ref.onDispose(() {
    supabase.removeChannel(sub);
  });

  // Fetch the aggregated leaderboard via RPC
  final response = await supabase.rpc('get_leaderboard');
  return List<Map<String, dynamic>>.from(response);
});

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Leaderboard'),
        centerTitle: true,
      ),
      body: leaderboardAsync.when(
        data: (rankings) {
          if (rankings.isEmpty) {
            return const Center(child: Text('No scores yet!'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rankings.length,
            itemBuilder: (context, index) {
              final rank = rankings[index];
              return Card(
                color: index == 0 ? Colors.amber.withOpacity(0.2) : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: index == 0 ? Colors.amber : Colors.grey,
                    child: Text('#${index + 1}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(rank['display_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  trailing: Text(rank['total_score'].toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading leaderboard: $err')),
      ),
    );
  }
}
