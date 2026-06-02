import 'package:flutter/material.dart';
import '../../../services/backend_service.dart';
import '../../../services/app_package.dart';
import '../../../l10n/app_localizations.dart';
import '../../details/presentation/details_page.dart';

class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  List<AppPackage> _installedApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final apps = await BackendService.instance.listInstalled();
    if (mounted) {
      setState(() {
        _installedApps = apps.map((a) => AppPackage.fromJson(a)).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Text(
                  "Installed Apps",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadApps,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _installedApps.isEmpty
                ? const Center(child: Text("No apps installed yet"))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _installedApps.length,
                    itemBuilder: (context, index) => _buildAppItem(_installedApps[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppItem(AppPackage app) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: app.icon != null ? Image.network(app.icon!) : const Icon(Icons.apps),
        ),
        title: Text(app.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${app.primarySource} • ${app.version}"),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)));
        },
      ),
    );
  }
}
