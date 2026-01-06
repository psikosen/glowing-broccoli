import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:async';
import '../services/memory_engine.dart';
import '../database/database.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MemoryEngine _memoryEngine = MemoryEngine();
  MemoryStats? _stats;
  String? _currentActivity;
  bool _isServiceRunning = false;
  StreamSubscription? _serviceSubscription;

  String? _pendingPrototypeId;
  final TextEditingController _labelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeService();
    _loadStats();
    _listenToService();
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    final service = FlutterBackgroundService();
    _isServiceRunning = await service.isRunning();
    setState(() {});
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _memoryEngine.getMemoryStats();
      setState(() {
        _stats = stats;
      });
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  void _listenToService() {
    final service = FlutterBackgroundService();

    _serviceSubscription = service.on('novel_context').listen((event) {
      setState(() {
        _pendingPrototypeId = event?['prototype_id'] as String?;
      });
      _showLabelDialog();
    });

    service.on('memory_stats').listen((event) {
      _loadStats();
    });
  }

  Future<void> _showLabelDialog() async {
    if (_pendingPrototypeId == null) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Context Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('What are you doing right now?'),
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                hintText: 'e.g., Walking, Cooking, Studying',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (_) => _submitLabel(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _labelController.clear();
              _pendingPrototypeId = null;
            },
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: _submitLabel,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitLabel() async {
    if (_labelController.text.trim().isEmpty || _pendingPrototypeId == null) {
      return;
    }

    try {
      await _memoryEngine.updatePrototypeLabel(
        _pendingPrototypeId!,
        _labelController.text.trim(),
      );

      setState(() {
        _currentActivity = _labelController.text.trim();
      });

      _labelController.clear();
      _pendingPrototypeId = null;

      if (mounted) {
        Navigator.pop(context);
      }

      await _loadStats();
    } catch (e) {
      print('Error updating label: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dear More'),
        actions: [
          IconButton(
            icon: Icon(_isServiceRunning ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              // Toggle service
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildStatsCard(),
            const SizedBox(height: 16),
            _buildActivityDistributionCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isServiceRunning ? Icons.check_circle : Icons.error,
                  color: _isServiceRunning ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _isServiceRunning ? 'Active' : 'Inactive',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_currentActivity != null)
              Text(
                'Current: $_currentActivity',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_stats == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Memory Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildStatRow('Total Prototypes', _stats!.totalPrototypes.toString()),
            _buildStatRow('Labeled', _stats!.labeledPrototypes.toString()),
            _buildStatRow('Unlabeled', _stats!.unlabeledPrototypes.toString()),
            _buildStatRow('Replay Buffer', _stats!.replayBufferSize.toString()),
            _buildStatRow(
              'Database Size',
              '${(_stats!.databaseSize / 1024 / 1024).toStringAsFixed(2)} MB',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityDistributionCard() {
    if (_stats == null || _stats!.labelDistribution.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Distribution',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._stats!.labelDistribution.entries.map((entry) {
              final percentage =
                  (entry.value / _stats!.totalPrototypes * 100).toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.key)),
                    Text('$percentage%'),
                    const SizedBox(width: 8),
                    Text(
                      '(${entry.value})',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
