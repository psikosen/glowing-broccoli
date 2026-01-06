import 'package:flutter/material.dart';
import '../database/database.dart';
import '../services/memory_engine.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  List<Prototype> _prototypes = [];
  bool _isLoading = true;
  String? _filterLabel;

  @override
  void initState() {
    super.initState();
    _loadPrototypes();
  }

  Future<void> _loadPrototypes() async {
    setState(() => _isLoading = true);

    try {
      final db = AppDatabase.instance;
      final prototypes = _filterLabel == null
          ? await db.getAllPrototypes()
          : await db.getPrototypesByLabel(_filterLabel!);

      setState(() {
        _prototypes = prototypes;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading prototypes: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePrototype(String id) async {
    try {
      final db = AppDatabase.instance;
      await db.deletePrototype(id);
      await _loadPrototypes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory deleted')),
        );
      }
    } catch (e) {
      print('Error deleting prototype: $e');
    }
  }

  Future<void> _editLabel(Prototype prototype) async {
    final controller = TextEditingController(text: prototype.label ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Activity name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final memoryEngine = MemoryEngine();
              await memoryEngine.updatePrototypeLabel(
                prototype.id,
                controller.text.trim(),
              );
              Navigator.pop(context);
              await _loadPrototypes();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Bank'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrototypes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _prototypes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.psychology_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No memories yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start using the app to build your digital twin',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _prototypes.length,
                  itemBuilder: (context, index) {
                    final prototype = _prototypes[index];
                    return _buildPrototypeCard(prototype);
                  },
                ),
    );
  }

  Widget _buildPrototypeCard(Prototype prototype) {
    final isLabeled = prototype.label != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLabeled ? Colors.blue : Colors.grey,
          child: Text(
            isLabeled ? prototype.label![0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(prototype.label ?? 'Unlabeled'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Observed ${prototype.count} times'),
            Text(
              'Last seen: ${_formatDateTime(prototype.lastSeen)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit Label'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _editLabel(prototype);
            } else if (value == 'delete') {
              _showDeleteConfirmation(prototype);
            }
          },
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _showFilterDialog() async {
    final db = AppDatabase.instance;
    final prototypes = await db.getAllPrototypes();
    final labels = prototypes
        .where((p) => p.label != null)
        .map((p) => p.label!)
        .toSet()
        .toList();

    if (mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Filter by Activity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All'),
                onTap: () {
                  setState(() => _filterLabel = null);
                  Navigator.pop(context);
                  _loadPrototypes();
                },
              ),
              ...labels.map((label) => ListTile(
                    title: Text(label),
                    onTap: () {
                      setState(() => _filterLabel = label);
                      Navigator.pop(context);
                      _loadPrototypes();
                    },
                  )),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmation(Prototype prototype) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Memory?'),
        content: Text(
          'Are you sure you want to delete "${prototype.label ?? 'Unlabeled'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _deletePrototype(prototype.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
