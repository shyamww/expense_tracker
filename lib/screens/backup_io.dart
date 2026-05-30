import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

/// iOS requires a non-zero global rect to anchor the share sheet.
Rect _sharePositionOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize) {
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.width > 0 && rect.height > 0) return rect;
  }
  final size = MediaQuery.sizeOf(context);
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 1,
    height: 1,
  );
}

Future<void> shareBackup(BuildContext context, String jsonString) async {
  final tempDir = Directory.systemTemp;
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final file = File(p.join(tempDir.path, 'expense_backup_$timestamp.bak'));
  await file.writeAsString(jsonString);

  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'Expense Tracker Backup',
    sharePositionOrigin: _sharePositionOrigin(context),
  );
}

Future<String> readFile(String path) async {
  return await File(path).readAsString();
}
