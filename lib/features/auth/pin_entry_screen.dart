import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ascend_arena/core/providers.dart';
import 'package:ascend_arena/features/auth/local_auth_service.dart';
import 'package:ascend_arena/main.dart'; // For RoleRouter

class PinEntryScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> account;
  
  const PinEntryScreen({super.key, required this.account});

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _verifyPin(String pin) async {
    setState(() {
      _error = null;
      _isLoading = true;
    });

    if (pin != widget.account['pin']) {
      setState(() {
        _error = 'Incorrect PIN';
        _pinController.clear();
        _isLoading = false;
      });
      return;
    }

    // PIN is correct, re-hydrate Supabase session
    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase.auth.setSession(widget.account['refresh_token']);
      
      if (response.session != null) {
        // Update the refresh token locally in case it was rotated
        final localAuth = ref.read(localAuthServiceProvider);
        await localAuth.updateRefreshToken(widget.account['id'], response.session!.refreshToken!);

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const RoleRouter()),
            (route) => false,
          );
        }
      } else {
        throw Exception('Failed to restore session. Token may be expired.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Session expired. Please re-add account.';
          _isLoading = false;
        });
        
        // Optionally remove the dead account
        // ref.read(localAuthServiceProvider).removeAccount(widget.account['id']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter PIN')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.amber,
                child: Text(
                  widget.account['display_name'][0].toUpperCase(),
                  style: const TextStyle(fontSize: 32, color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome back, ${widget.account['display_name']}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Pinput(
                  controller: _pinController,
                  length: 4,
                  obscureText: true,
                  autofocus: true,
                  onCompleted: _verifyPin,
                  errorText: _error,
                  forceErrorState: _error != null,
                ),
                
              const SizedBox(height: 24),
              if (_error != null)
                TextButton(
                  onPressed: () async {
                    await ref.read(localAuthServiceProvider).removeAccount(widget.account['id']);
                    if (mounted) Navigator.pop(context); // Go back to profile selection
                  },
                  child: const Text('Remove this account', style: TextStyle(color: Colors.red)),
                )
            ],
          ),
        ),
      ),
    );
  }
}
