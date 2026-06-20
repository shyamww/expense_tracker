import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/material.dart';

Future<void> shareBackup(BuildContext context, String jsonString) async {
  final bytes = utf8.encode(jsonString);
  final blob = html.Blob([bytes], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', 'expense_backup.bak')
    ..click();

  html.Url.revokeObjectUrl(url);
}

Future<String> readFile(String path) async {
  throw UnsupportedError('readFile is not supported on web');
}
