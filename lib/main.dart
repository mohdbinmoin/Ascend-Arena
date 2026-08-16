import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ascend_arena/features/auth/profile_selection_screen.dart';
import 'package:ascend_arena/core/providers.dart';
import 'package:ascend_arena/features/admin/admin_dashboard.dart';
import 'package:ascend_arena/features/tasks/user_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fdzrkzgdbgxlvojuhhyw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkenJremdkYmd4bHZvanVoaHl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MTY2ODYsImV4cCI6MjEwMjA5MjY4Nn0.QUeSxKOg9XDoGgLoA0PcNPPVppB5fOjuEcJIHQR5_hk',
  );

  runApp(const ProviderScope(child: AscendArenaApp()));
}

class AscendArenaApp extends StatelessWidget {
  const AscendArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ascend Arena',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const ProfileSelectionScreen(), // App always starts here now
    );
  }
}

class RoleRouter extends ConsumerWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(userRoleProvider);

    return userRole.when(
      data: (role) {
        if (role == 'admin') {
          return const AdminDashboard();
        } else if (role == 'user') {
          return const UserDashboard();
        }
        // Fallback if role is unknown or missing
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Unknown role: $role'),
                TextButton(
                  onPressed: () {
                    ref.read(supabaseProvider).auth.signOut(scope: SignOutScope.local);
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
                      (route) => false,
                    );
                  }, 
                  child: const Text('Go Back')
                )
              ],
            )
          )
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Error loading role: $error'))),
    );
  }
}
