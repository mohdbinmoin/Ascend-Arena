import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
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

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Color _getRankColor(String rank) {
    if (rank.contains('Bronze')) return Colors.brown.shade400;
    if (rank.contains('Silver')) return Colors.grey.shade400;
    if (rank.contains('Gold')) return Colors.amber;
    if (rank.contains('Platinum')) return Colors.tealAccent;
    if (rank.contains('Diamond')) return Colors.blueAccent;
    if (rank.contains('Ascendant')) return Colors.purpleAccent;
    if (rank.contains('Champion')) return Colors.redAccent;
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arena Leaderboard', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          leaderboardAsync.when(
            data: (rankings) {
              if (rankings.isEmpty) {
                return const Center(child: Text('No players ranked yet!'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rankings.length,
                itemBuilder: (context, index) {
                  final rank = rankings[index];
                  final isTop3 = index < 3;
                  
                  return Card(
                    elevation: isTop3 ? 8 : 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isTop3 
                          ? BorderSide(color: Colors.amber, width: index == 0 ? 3 : 1) 
                          : BorderSide.none,
                    ),
                    color: index == 0 ? Colors.amber.withValues(alpha: 0.15) : Colors.grey.shade900,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // Rank Circle
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: index == 0 ? Colors.amber : (index == 1 ? Colors.grey.shade400 : (index == 2 ? Colors.brown.shade400 : Colors.grey.shade800)),
                            child: Text('#${index + 1}', style: TextStyle(color: index < 3 ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          ),
                          const SizedBox(width: 16),
                          
                          // Avatar
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey.shade800,
                            backgroundImage: rank['avatar_url'] != null ? NetworkImage(rank['avatar_url']) : null,
                            child: rank['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 16),
                          
                          // Name and Rank
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rank['display_name'], 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getRankColor(rank['current_rank'] ?? 'Bronze 5').withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _getRankColor(rank['current_rank'] ?? 'Bronze 5')),
                                  ),
                                  child: Text(
                                    rank['current_rank'] ?? 'Bronze 5',
                                    style: TextStyle(
                                      color: _getRankColor(rank['current_rank'] ?? 'Bronze 5'),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold
                                    )
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Level & XP
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Lvl ${rank['level']}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              Text(
                                '${rank['xp']} XP', 
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fade(duration: 400.ms).slideX(begin: 0.2, curve: Curves.easeOut),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading leaderboard: $err')),
          ),
          
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 20,
              minBlastForce: 5,
              colors: const [Colors.amber, Colors.orange, Colors.yellow, Colors.white],
            ),
          ),
        ],
      ),
    );
  }
}
