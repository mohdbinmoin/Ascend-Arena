import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascend_arena/features/auth/local_auth_service.dart';
import 'package:ascend_arena/features/auth/auth_screen.dart'; // The original email/password screen
import 'package:ascend_arena/features/auth/pin_entry_screen.dart';

class ProfileSelectionScreen extends ConsumerStatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  ConsumerState<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends ConsumerState<ProfileSelectionScreen> {
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final localAuth = ref.read(localAuthServiceProvider);
    final accounts = await localAuth.getSavedAccounts();
    setState(() {
      _accounts = accounts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Who's Playing?",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              
              if (_accounts.isEmpty)
                const Text('No accounts saved on this device yet.')
              else
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  alignment: WrapAlignment.center,
                  children: _accounts.map((acc) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PinEntryScreen(account: acc)),
                        );
                      },
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.amber,
                            child: Text(
                              acc['display_name'][0].toUpperCase(),
                              style: const TextStyle(fontSize: 32, color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(acc['display_name'], style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                
              const SizedBox(height: 64),
              
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  ).then((_) => _loadAccounts()); // Reload accounts after returning
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Account'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
