// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

class FileDownloader {
  /// Initiates browser download for a given URL (HTTP, Blob, or base64 data URI)
  static void downloadUrl(String url, String fileName) {
    try {
      if (url.startsWith('data:')) {
        final commaIdx = url.indexOf(',');
        if (commaIdx != -1) {
          final header = url.substring(0, commaIdx);
          final base64Str = url.substring(commaIdx + 1);
          final bytes = base64Decode(base64Str);
          final mimeMatch = RegExp(r'data:([^;]+);').firstMatch(header);
          final mime = mimeMatch != null ? mimeMatch.group(1)! : 'application/octet-stream';
          final blob = html.Blob([bytes], mime);
          final blobUrl = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: blobUrl)
            ..setAttribute('download', fileName)
            ..style.display = 'none';
          html.document.body?.children.add(anchor);
          anchor.click();
          anchor.remove();
          Future.delayed(const Duration(seconds: 2), () {
            html.Url.revokeObjectUrl(blobUrl);
          });
          return;
        }
      }

      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..target = '_blank'
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
    } catch (_) {
      try {
        html.window.open(url, '_blank');
      } catch (_) {}
    }
  }

  /// Downloads raw byte content directly
  static void downloadBytes(Uint8List bytes, String fileName, {String mimeType = 'application/octet-stream'}) {
    try {
      final blob = html.Blob([bytes], mimeType);
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: blobUrl)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
      Future.delayed(const Duration(seconds: 2), () {
        html.Url.revokeObjectUrl(blobUrl);
      });
    } catch (_) {}
  }
}
