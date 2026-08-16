import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ascend_arena/core/providers.dart';
import 'package:ascend_arena/features/auth/local_auth_service.dart';
import 'package:ascend_arena/main.dart'; // For RoleRouter

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinController = TextEditingController();
  bool _isSaving = false;

  Future<void> _savePinAndAccount(String pin) async {
    setState(() => _isSaving = true);
    
    try {
      final supabase = ref.read(supabaseProvider);
      final session = supabase.auth.currentSession;
      final user = supabase.auth.currentUser;
      
      if (session == null || user == null) throw Exception('No active session');

      // Fetch display name
      final response = await supabase.from('users').select('display_name').eq('id', user.id).single();
      final displayName = response['display_name'] as String? ?? user.email ?? 'Unknown';

      // Save to local storage
      final localAuth = ref.read(localAuthServiceProvider);
      await localAuth.saveAccount(
        id: user.id,
        email: user.email ?? '',
        displayName: displayName,
        refreshToken: session.refreshToken ?? '',
        pin: pin,
      );

      if (mounted) {
        // Navigate to the router, clearing stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RoleRouter()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving account: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup PIN'), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.amber),
              const SizedBox(height: 24),
              const Text(
                'Create a 4-digit PIN',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will let you quickly switch to this account next time without a password.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 48),
              if (_isSaving)
                const CircularProgressIndicator()
              else
                Pinput(
                  controller: _pinController,
                  length: 4,
                  obscureText: true,
                  autofocus: true,
                  onCompleted: _savePinAndAccount,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
