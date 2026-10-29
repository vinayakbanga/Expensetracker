import 'platform_file_stub.dart'
    if (dart.library.io) 'platform_file_io.dart'
    if (dart.library.js_interop) 'platform_file_web.dart' as impl;

abstract class PlatformFileHelper {
  static Future<String> writeTempCsv(String content) => impl.writeTempCsv(content);
  static Future<String?> readString(String path) => impl.readString(path);
  static bool exists(String path) => impl.exists(path);
}

