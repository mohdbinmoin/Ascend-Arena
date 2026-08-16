import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascend_arena/core/providers.dart';

final trophiesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('trophies')
      .select('*, seasons(name)')
      .eq('user_id', userId)
      .order('awarded_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

class TrophyCabinetScreen extends ConsumerWidget {
  final String userId;
  final String displayName;

  const TrophyCabinetScreen({super.key, required this.userId, required this.displayName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trophiesAsync = ref.watch(trophiesProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text('$displayName\'s Trophies')),
      body: trophiesAsync.when(
        data: (trophies) {
          if (trophies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No trophies yet. Keep working hard!'),
                ],
              ),
            );
          }
          
          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: trophies.length,
            itemBuilder: (context, index) {
              final trophy = trophies[index];
              final type = trophy['type'] as String;
              
              Color trophyColor;
              if (type.toLowerCase() == 'gold') trophyColor = Colors.amber;
              else if (type.toLowerCase() == 'silver') trophyColor = Colors.grey.shade400;
              else trophyColor = Colors.brown.shade400; // Bronze
              
              return Card(
                color: trophyColor.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: trophyColor, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, size: 64, color: trophyColor),
                    const SizedBox(height: 8),
                    Text(
                      type.toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.bold, color: trophyColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trophy['seasons']?['name'] ?? 'All Time',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
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
