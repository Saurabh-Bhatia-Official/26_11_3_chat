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
  
  // 3. Check workspace ephemeral SPM directories
  final currentDir = Directory.current.path;
  final possibleLocalDirs = [
    '$currentDir/macos/Flutter/ephemeral',
    '$currentDir/frontend/macos/Flutter/ephemeral',
    '$currentDir/ios/Flutter/ephemeral',
    '$currentDir/frontend/ios/Flutter/ephemeral',
  ];
  
  for (final localPath in possibleLocalDirs) {
    final dir = Directory(localPath);
    if (dir.existsSync()) {
      searchRoots.add(dir);
    }
  }
  
  int patchedCount = 0;
  
  for (final root in searchRoots) {
    if (!root.existsSync()) continue;
    print('Searching in: ${root.path}');
    
    try {
      final entities = root.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is! File) continue;
        
        final path = entity.path;
        if (!path.endsWith('.h')) continue;
        if (!path.contains('flutter_webrtc')) continue;
        
        final filename = entity.uri.pathSegments.last;
        // Targeted headers that use TARGET_OS_ conditionals
        const targetHeaders = {
          'FlutterWebRTCPlugin.h',
          'FlutterRTCFrameCryptor.h',
          'FlutterRTCDesktopCapturer.h',
          'FlutterDataPacketCryptor.h',
          'FlutterRTCFrameCapturer.h',
          'AudioUtils.h',
          'FlutterRPScreenRecorder.h',
        };
        
        if (!targetHeaders.contains(filename)) continue;
        
        try {
          final content = entity.readAsStringSync();
          if (content.contains('#import <TargetConditionals.h>') ||
              content.contains('#include <TargetConditionals.h>')) {
            // Already patched
            continue;
          }
          
          if (content.contains('TARGET_OS_')) {
            final patchedContent = '#import <TargetConditionals.h>\n' + content;
            entity.writeAsStringSync(patchedContent);
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
