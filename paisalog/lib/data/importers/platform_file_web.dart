final Map<String, String> _webFileCache = {};

Future<String> writeTempCsv(String content) async {
  final path = 'paisalog_export_${DateTime.now().millisecondsSinceEpoch}.csv';
  _webFileCache[path] = content;
  return path;
}

Future<String?> readString(String path) async {
  return _webFileCache[path];
}

bool exists(String path) => _webFileCache.containsKey(path);

