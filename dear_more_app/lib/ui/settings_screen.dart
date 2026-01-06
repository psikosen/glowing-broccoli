import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/memory_engine.dart';
import '../database/database.dart';
import '../services/sync_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoSync = true;
  String _serverUrl = 'https://api.dearmore.ai';
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSync = prefs.getBool('auto_sync') ?? true;
      _serverUrl = prefs.getString('server_url') ?? 'https://api.dearmore.ai';
      final lastSyncTimestamp = prefs.getInt('last_sync');
      if (lastSyncTimestamp != null) {
        _lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp);
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync', _autoSync);
    await prefs.setString('server_url', _serverUrl);
  }

  Future<void> _performManualSync() async {
    try {
      final syncService = SyncService();
      await syncService.syncWithServer();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_sync', DateTime.now().millisecondsSinceEpoch);

      setState(() {
        _lastSync = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will delete all learned memories and cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = AppDatabase.instance;
        await db.delete(db.prototypes).go();
        await db.delete(db.replayBuffer).go();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All data cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing data: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSection('Sync Settings'),
          SwitchListTile(
            title: const Text('Auto Sync'),
            subtitle: const Text('Automatically sync with server when charging'),
            value: _autoSync,
            onChanged: (value) {
              setState(() => _autoSync = value);
              _saveSettings();
            },
          ),
          ListTile(
            title: const Text('Server URL'),
            subtitle: Text(_serverUrl),
            trailing: const Icon(Icons.edit),
            onTap: _editServerUrl,
          ),
          ListTile(
            title: const Text('Manual Sync'),
            subtitle: _lastSync != null
                ? Text('Last synced: ${_formatDateTime(_lastSync!)}')
                : const Text('Never synced'),
            trailing: const Icon(Icons.sync),
            onTap: _performManualSync,
          ),
          const Divider(),
          _buildSection('Privacy & Security'),
          ListTile(
            title: const Text('Database Encryption'),
            subtitle: const Text('Enabled (SQLCipher)'),
            trailing: const Icon(Icons.lock, color: Colors.green),
          ),
          ListTile(
            title: const Text('Data Retention'),
            subtitle: const Text('Automatic cleanup after 500MB'),
          ),
          const Divider(),
          _buildSection('Advanced'),
          ListTile(
            title: const Text('Genesis Threshold'),
            subtitle: Text('τ = ${MemoryEngine.genesisThreshold}'),
            trailing: const Icon(Icons.tune),
          ),
          ListTile(
            title: const Text('Learning Rate'),
            subtitle: Text('α = ${MemoryEngine.fastLearningRate}'),
            trailing: const Icon(Icons.tune),
          ),
          const Divider(),
          _buildSection('Danger Zone'),
          ListTile(
            title: const Text('Clear All Data'),
            subtitle: const Text('Delete all learned memories'),
            trailing: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: _clearAllData,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Dear More v1.0.0\nEdge-Cloud Digital Twin with Continual Learning',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays > 0) {
      return '${diff.inDays} days ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hours ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _editServerUrl() async {
    final controller = TextEditingController(text: _serverUrl);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Server URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://api.dearmore.ai',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _serverUrl = controller.text);
              _saveSettings();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
