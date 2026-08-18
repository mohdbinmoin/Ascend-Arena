import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ascend_arena/features/auth/profile_selection_screen.dart';
import 'package:ascend_arena/features/auth/local_auth_service.dart';
import 'package:ascend_arena/core/providers.dart';
import 'package:ascend_arena/features/admin/admin_dashboard.dart';
import 'package:ascend_arena/features/tasks/user_dashboard.dart';
import 'package:ascend_arena/core/offline_storage.dart';
import 'package:ascend_arena/core/background_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await OfflineStorage.init();
  await BackgroundSync.init();

  await Supabase.initialize(
    url: 'https://fdzrkzgdbgxlvojuhhyw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkenJremdkYmd4bHZvanVoaHl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MTY2ODYsImV4cCI6MjEwMjA5MjY4Nn0.QUeSxKOg9XDoGgLoA0PcNPPVppB5fOjuEcJIHQR5_hk',
  );

  runApp(const ProviderScope(child: AscendArenaApp()));
}

class AscendArenaApp extends ConsumerStatefulWidget {
  const AscendArenaApp({super.key});

  @override
  ConsumerState<AscendArenaApp> createState() => _AscendArenaAppState();
}

class _AscendArenaAppState extends ConsumerState<AscendArenaApp> {
  @override
  void initState() {
    super.initState();
    // Listen for refresh token rotations and update secure storage
    final supabase = ref.read(supabaseProvider);
    supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null && session.refreshToken != null) {
        ref.read(localAuthServiceProvider).updateRefreshToken(
          session.user.id, 
          session.refreshToken!
        );
      }
    });
  }

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
