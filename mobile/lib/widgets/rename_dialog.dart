import 'dart:io';

import 'package:flutter/material.dart';

import '../csv_logger.dart';

/// Prompts the user to rename [file] before sharing it, pre-filled with its
/// current name. Returns the file at its final path (renamed if the user
/// changed the name), or null if the user cancelled.
Future<File?> promptRenameBeforeSharing(BuildContext context, File file) async {
  final currentBase = file.uri.pathSegments.last.replaceAll(RegExp(r'\.csv$'), '');
  final controller = TextEditingController(text: currentBase);

  final newBase = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Nom du fichier'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nom (sans .csv)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('Partager'),
        ),
      ],
    ),
  );
  if (newBase == null) return null;

  final sanitized = CsvLogger.sanitizeBaseName(newBase);
  if (sanitized == currentBase) return file;
  return CsvLogger.renameFile(file, sanitized);
}
