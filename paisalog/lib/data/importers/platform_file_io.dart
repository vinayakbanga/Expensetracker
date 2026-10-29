import 'dart:convert';
import 'dart:io';

Future<String> writeTempCsv(String content) async {
  final tmpDir = Directory.systemTemp;
  final file = File(
      '${tmpDir.path}/paisalog_export_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(content, encoding: const Utf8Codec());
  return file.path;
}

Future<String?> readString(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  return await file.readAsString();
}

bool exists(String path) => File(path).existsSync();

