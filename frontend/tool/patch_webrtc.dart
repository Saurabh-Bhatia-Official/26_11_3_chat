import 'dart:io';

void main() {
  print('=== Running flutter_webrtc Header Patcher for macOS/iOS SPM ===');

  final List<Directory> searchRoots = [];

  // 1. Check PUB_CACHE environment variable
  final pubCacheEnv = Platform.environment['PUB_CACHE'];
  if (pubCacheEnv != null && pubCacheEnv.isNotEmpty) {
    searchRoots.add(Directory(pubCacheEnv));
  }

  // 2. Check standard user pub cache paths
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    final defaultUnixPubCache = Directory('$home/.pub-cache');
    if (defaultUnixPubCache.existsSync()) {
      searchRoots.add(defaultUnixPubCache);
    }
  }

  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null && localAppData.isNotEmpty) {
    final defaultWinPubCache = Directory('$localAppData/Pub/Cache');
    if (defaultWinPubCache.existsSync()) {
      searchRoots.add(defaultWinPubCache);
    }
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    final flutterPubCache = Directory('$flutterRoot/.pub-cache');
    if (flutterPubCache.existsSync()) {
      searchRoots.add(flutterPubCache);
    }
  }

  // 3. Check workspace directories
  final currentDir = Directory.current.path;
  searchRoots.add(Directory(currentDir));

  final parentDir = Directory.current.parent.path;
  if (parentDir != currentDir) {
    searchRoots.add(Directory(parentDir));
  }

  int patchedCount = 0;
  final Set<String> processedPaths = {};

  for (final root in searchRoots) {
    if (!root.existsSync()) continue;
    print('Searching in: ${root.path}');

    try {
      final entities = root.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is! File) continue;

        final path = entity.path;
        final hasSupportedExt = path.endsWith('.h') ||
            path.endsWith('.m') ||
            path.endsWith('.mm') ||
            path.endsWith('.c') ||
            path.endsWith('.cpp') ||
            path.endsWith('.hpp');
        if (!hasSupportedExt) continue;
        if (!path.contains('flutter_webrtc')) continue;

        if (processedPaths.contains(path)) continue;
        processedPaths.add(path);

        try {
          String content = entity.readAsStringSync();
          bool needsWrite = false;

          // Fix accidental literal 'n' from BSD sed if present
          if (content.contains('#import <TargetConditionals.h>n')) {
            content = content.replaceAll('#import <TargetConditionals.h>n', '#import <TargetConditionals.h>\n');
            needsWrite = true;
          }

          if (content.contains('TARGET_OS_') &&
              !content.contains('#import <TargetConditionals.h>') &&
              !content.contains('#include <TargetConditionals.h>')) {
            content = '#import <TargetConditionals.h>\n' + content;
            needsWrite = true;
          }

          if (needsWrite) {
            entity.writeAsStringSync(content);
            print('  -> Patched: $path');
            patchedCount++;
          }
        } catch (e) {
          print('  [Warning] Could not process $path: $e');
        }
      }
    } catch (e) {
      print('  [Warning] Error scanning ${root.path}: $e');
    }
  }

  print('=== Header patcher completed. Patched $patchedCount file(s). ===');
}
