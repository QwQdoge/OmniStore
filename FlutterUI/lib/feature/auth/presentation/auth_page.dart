import 'package:flutter/material.dart';
import '../../../services/backend_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _patController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_rounded, size: 64, color: Colors.purple),
              const SizedBox(height: 24),
              const Text("GitHub Authentication", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Enter your Personal Access Token (PAT) for higher rate limits"),
              const SizedBox(height: 32),
              TextField(
                controller: _patController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Personal Access Token",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key_rounded),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  final config = await BackendService.instance.loadConfig();
                  config['github_store'] ??= {};
                  config['github_store']['pat'] = _patController.text;
                  await BackendService.instance.saveConfig(config);
                  if (mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text("Save Token"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
