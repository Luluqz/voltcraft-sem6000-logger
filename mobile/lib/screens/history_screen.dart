import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../csv_logger.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final files = await CsvLogger.listFiles();
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  String _label(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes o';
    return '${(bytes / 1024).toStringAsFixed(1)} Ko';
  }

  Future<void> _share(File f) async {
    await Share.shareXFiles([XFile(f.path)]);
  }

  Future<void> _confirmDelete(File f, DateTime modified) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cet enregistrement ?'),
        content: Text(_label(modified)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await CsvLogger.deleteFile(f);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des enregistrements')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _files.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Aucun enregistrement CSV pour le moment. '
                          'Ils apparaîtront ici après un "Démarrer '
                          'l\'enregistrement" dans l\'écran de mesure.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, i) {
                      final f = _files[i];
                      return FutureBuilder<FileStat>(
                        future: f.stat(),
                        builder: (context, snapshot) {
                          final stat = snapshot.data;
                          return ListTile(
                            leading: const Icon(Icons.description_outlined),
                            title: Text(
                                stat != null ? _label(stat.modified) : f.uri.pathSegments.last),
                            subtitle:
                                stat != null ? Text(_sizeLabel(stat.size)) : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.share_outlined),
                                  tooltip: 'Partager',
                                  onPressed: () => _share(f),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Supprimer',
                                  onPressed: () => _confirmDelete(
                                      f, stat?.modified ?? DateTime.now()),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
